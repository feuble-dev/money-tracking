import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';
import '../licence/licence_service.dart';
import '../sms/sms_field_extractor.dart';
import 'historique_storage.dart';

// Même URL que licence_service
const String _baseUrl = 'http://192.168.11.107:8000/api/licence';

class HistoriqueImportService {
  static const _smsChannel = MethodChannel('com.rftech.moneytracking/sms_inbox');

  /// Demander l'achat historique
  static Future<ResultatAchat> demanderAchat(String telephone) async {
    final deviceId = await LicenceService.getDeviceId();
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/historique/demander/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'telephone': telephone,
          'device_id': deviceId,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (data['statut'] == 'deja_active') {
        await HistoriqueStorage.sauvegarderToken(data['token']);
        return ResultatAchat.dejaActive();
      }

      return ResultatAchat.enAttente(
        data['message'] ?? 'Demande envoyée',
      );
    } catch (e) {
      return ResultatAchat.erreur('Impossible de se connecter');
    }
  }

  /// Polling: attendre validation
  static Stream<StatutAchat> attendreValidation(
    String telephone,
  ) async* {
    yield StatutAchat.enAttente;
    final deviceId = await LicenceService.getDeviceId();

    for (int i = 0; i < 2880; i++) {
      await Future.delayed(const Duration(seconds: 30));
      try {
        final response = await http.post(
          Uri.parse('$_baseUrl/historique/recuperer/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'telephone': telephone,
            'device_id': deviceId,
          }),
        );
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['statut'] == 'active') {
            await HistoriqueStorage.sauvegarderToken(data['token']);
            yield StatutAchat.active;
            return;
          }
        }
      } catch (_) {}
      yield StatutAchat.enAttente;
    }
    yield StatutAchat.timeout;
  }

  /// Importer les anciens SMS depuis la boîte de réception
  /// Workflow : pour chaque opérateur → filtrer par sender → tester regex dépôt/retrait
  /// → si match, vérifier doublon par operator_transaction_id → créer si nouveau
  static Future<ResultatImport> importerSMS({
    required DateTime dateDebut,
    required DateTime dateFin,
    required Function(int traites, int total) onProgress,
  }) async {
    final token = await HistoriqueStorage.getToken();
    if (token == null) {
      return ResultatImport.erreur('Achat non activé');
    }

    // 1. Lire TOUS les SMS via MethodChannel natif
    List<Map<String, dynamic>> allSms;
    try {
      final result = await _smsChannel.invokeMethod('getInboxSms', {
        'dateFrom': dateDebut.millisecondsSinceEpoch,
        'dateTo': dateFin.millisecondsSinceEpoch,
      });
      final rawList = result as List? ?? [];
      allSms = rawList.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      debugPrint('[Import] ${allSms.length} SMS lus depuis inbox');
    } catch (e) {
      debugPrint('[Import] MethodChannel error: $e');
      return ResultatImport.erreur(
          'Impossible de lire les SMS. Vérifiez la permission SMS.');
    }

    if (allSms.isEmpty) {
      return ResultatImport.vide();
    }

    final db = await DatabaseHelper.instance.database;

    // 2. Charger opérateurs + leurs patterns
    final operators = await db.query('operators', where: 'is_active = 1');
    if (operators.isEmpty) {
      return ResultatImport.erreur('Aucun opérateur configuré');
    }

    final patterns = await db.query('sms_patterns');

    // Organiser : { operatorId: { sms_sender, deposit_patterns, withdrawal_patterns } }
    final opConfigs = <String, _OpConfig>{};
    for (final op in operators) {
      final opId = op['id'] as String;
      final sender = (op['sms_sender'] as String?) ?? '';
      if (sender.isEmpty) continue;

      final depositPatterns = patterns
          .where((p) => p['operator_id'] == opId && p['transaction_type'] == 'deposit')
          .toList();
      final withdrawalPatterns = patterns
          .where((p) => p['operator_id'] == opId && p['transaction_type'] == 'withdrawal')
          .toList();

      opConfigs[opId] = _OpConfig(
        sender: sender,
        commissionDepot: (op['taux_commission_depot'] as num?)?.toDouble() ?? 0,
        commissionRetrait: (op['taux_commission_retrait'] as num?)?.toDouble() ?? 0,
        depositPatterns: depositPatterns,
        withdrawalPatterns: withdrawalPatterns,
      );
    }

    int totalAnalyses = 0;
    int crees = 0;
    int ignores = 0;
    final totalSms = allSms.length;

    // 3. Pour chaque opérateur
    for (final entry in opConfigs.entries) {
      final opId = entry.key;
      final config = entry.value;

      // Filtrer les SMS dont le sender correspond
      final opSms = allSms.where((sms) {
        final sender = (sms['address'] ?? '') as String;
        return sender.toLowerCase().contains(config.sender.toLowerCase());
      }).toList();

      debugPrint('[Import] ${config.sender}: ${opSms.length} SMS trouvés');

      // 4. Pour chaque SMS de cet opérateur
      for (final sms in opSms) {
        final body = (sms['body'] ?? '') as String;
        final dateMs = sms['date'] as int? ?? 0;
        final date = DateTime.fromMillisecondsSinceEpoch(dateMs);
        totalAnalyses++;

        if (body.isEmpty) continue;

        // 5. Tester regex dépôt puis retrait — PAS de fallback
        // Seuls les SMS qui matchent les patterns configurés sont pris
        String? txType;
        if (_matchesAnyPattern(body, config.depositPatterns)) {
          txType = 'deposit';
        } else if (_matchesAnyPattern(body, config.withdrawalPatterns)) {
          txType = 'withdrawal';
        }

        // Aucun pattern matché → ce n'est PAS une transaction → ignorer
        if (txType == null) {
          ignores++;
          if (totalAnalyses % 20 == 0) onProgress(totalAnalyses, totalSms);
          continue;
        }

        // 6. Extraire les champs
        final extracted = SmsFieldExtractor.extractAll(body);
        final montantStr = extracted['montant'];
        if (montantStr == null) {
          ignores++;
          if (totalAnalyses % 20 == 0) onProgress(totalAnalyses, totalSms);
          continue;
        }

        final amount = SmsFieldExtractor.parseMontant(montantStr) ?? 0;
        if (amount <= 0) {
          ignores++;
          if (totalAnalyses % 20 == 0) onProgress(totalAnalyses, totalSms);
          continue;
        }

        final opTxId = extracted['operator_transaction_id'];

        // 7. Vérifier doublon par operator_transaction_id (le plus fiable)
        if (opTxId != null && opTxId.isNotEmpty) {
          final existing = await db.query('transactions',
              where: 'operator_transaction_id = ?',
              whereArgs: [opTxId],
              limit: 1);
          if (existing.isNotEmpty) {
            ignores++;
            if (totalAnalyses % 20 == 0) onProgress(totalAnalyses, totalSms);
            continue;
          }
        } else {
          // Fallback doublon par montant + date
          final existing = await db.query('transactions',
              where: 'operator_id = ? AND amount = ? AND created_at LIKE ?',
              whereArgs: [opId, amount, '${date.toIso8601String().substring(0, 16)}%'],
              limit: 1);
          if (existing.isNotEmpty) {
            ignores++;
            if (totalAnalyses % 20 == 0) onProgress(totalAnalyses, totalSms);
            continue;
          }
        }

        // 8. Calculer commission
        final commRate = txType == 'deposit'
            ? config.commissionDepot
            : config.commissionRetrait;
        final commission = amount * commRate / 100;

        // 9. Créer la transaction
        final txId = 'imp_${date.millisecondsSinceEpoch}_$crees';
        await db.insert('transactions', {
          'id': txId,
          'operator_id': opId,
          'transaction_type': txType,
          'amount': amount,
          'commission': commission,
          'client_phone': extracted['numero_client'] ?? '',
          'client_name': extracted['nom_client'],
          'operator_transaction_id': opTxId,
          'status': 'completed',
          'source': 'sms_import',
          'sms_raw': body,
          'created_at': date.toIso8601String(),
        });
        crees++;

        if (totalAnalyses % 20 == 0) onProgress(totalAnalyses, totalSms);
      }
    }

    onProgress(totalSms, totalSms);

    // Rafraîchir le cache
    if (crees > 0) {
      await DatabaseHelper.instance.refreshAllSummaries(db);
    }

    return ResultatImport.succes(
      total: totalAnalyses,
      crees: crees,
      ignores: ignores,
    );
  }

  /// Teste si un SMS matche au moins un pattern d'un opérateur
  /// Strict : regex d'abord, puis comparaison structurelle avec l'exemple
  static bool _matchesAnyPattern(
      String body, List<Map<String, dynamic>> patterns) {
    final bodyLower = body.toLowerCase();

    for (final p in patterns) {
      // 1. Tester le regex généré (le plus fiable)
      final regexStr = p['regex_generated'] as String?;
      if (regexStr != null && regexStr.isNotEmpty) {
        try {
          final regex = RegExp(regexStr, caseSensitive: false);
          if (regex.hasMatch(body)) return true;
        } catch (_) {}
      }

      // 2. Comparaison structurelle stricte avec l'exemple SMS
      // Le SMS doit contenir les mêmes phrases-clés (pas juste des mots isolés)
      final rawExample = (p['raw_example'] as String?) ?? '';
      if (rawExample.length > 20) {
        final phrases = _extractKeyPhrases(rawExample);
        if (phrases.isNotEmpty) {
          // TOUTES les phrases-clés doivent être présentes (strict)
          final allMatch = phrases.every(
              (phrase) => bodyLower.contains(phrase.toLowerCase()));
          if (allMatch) return true;
        }
      }
    }
    return false;
  }

  /// Extrait des phrases-clés discriminantes d'un SMS exemple
  /// Ex: "Vous avez transfere 50000 FCFA" → ["vous avez transfere", "fcfa"]
  static List<String> _extractKeyPhrases(String example) {
    final lower = example.toLowerCase();
    final phrases = <String>[];

    // Chercher des phrases discriminantes de transaction
    final discriminants = [
      // Dépôts
      r'vous avez transfere',
      r'vous avez envoye',
      r'depot de',
      r'transfert de',
      r'envoye a',
      r'transfere a',
      // Retraits
      r'vous avez recu',
      r'retrait de',
      r'a retire',
      r'received from',
      r'vous a envoye',
      r'credit de',
    ];

    for (final d in discriminants) {
      if (lower.contains(d)) {
        phrases.add(d);
      }
    }

    // Si aucune phrase standard trouvée, extraire la structure
    // (mots autour de "FCFA" qui ne sont pas des nombres)
    if (phrases.isEmpty) {
      final fcfaMatch = RegExp(
        r'([a-zà-ÿ\s]{10,})\d[\d\s.,]*\s*fcfa',
        caseSensitive: false,
      ).firstMatch(lower);
      if (fcfaMatch != null) {
        final prefix = fcfaMatch.group(1)!.trim();
        if (prefix.length >= 8) {
          phrases.add(prefix);
        }
      }
    }

    return phrases;
  }
}

class _OpConfig {
  final String sender;
  final double commissionDepot;
  final double commissionRetrait;
  final List<Map<String, dynamic>> depositPatterns;
  final List<Map<String, dynamic>> withdrawalPatterns;

  _OpConfig({
    required this.sender,
    required this.commissionDepot,
    required this.commissionRetrait,
    required this.depositPatterns,
    required this.withdrawalPatterns,
  });
}

enum StatutAchat { enAttente, active, timeout }

class ResultatAchat {
  final bool succes;
  final bool dejaActive;
  final String message;
  ResultatAchat.dejaActive()
      : succes = true,
        dejaActive = true,
        message = 'Déjà activé';
  ResultatAchat.enAttente(this.message)
      : succes = false,
        dejaActive = false;
  ResultatAchat.erreur(this.message)
      : succes = false,
        dejaActive = false;
}

class ResultatImport {
  final bool succes;
  final int total;
  final int crees;
  final int ignores;
  final String message;

  ResultatImport.succes({
    required this.total,
    required this.crees,
    required this.ignores,
  })  : succes = true,
        message = '$crees transactions créées sur $total SMS analysés';

  ResultatImport.vide()
      : succes = true,
        total = 0,
        crees = 0,
        ignores = 0,
        message = 'Aucun SMS trouvé sur cette période';

  ResultatImport.erreur(this.message)
      : succes = false,
        total = 0,
        crees = 0,
        ignores = 0;
}
