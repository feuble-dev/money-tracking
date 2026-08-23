import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../database/database_helper.dart';
import '../licence/licence_service.dart';
import '../sms/commission_calculator.dart';
import '../sms/sms_field_extractor.dart';
import '../sms/sms_matching_engine.dart';
import 'historique_storage.dart';

// Même URL que licence_service
const String _baseUrl = 'https://api-money-tracking.rf-appdev.online/api/licence';
// const String _baseUrl = 'http://localhost:8000/api/licence';

class HistoriqueImportService {
  static const _smsChannel = MethodChannel('com.rftech.moneytracking/sms_inbox');

  /// Aperçu client du coût (D5) — miroir exact de
  /// HistoriqueService.calculer_cout côté backend, qui reste la seule
  /// source de vérité pour le montant réellement facturé.
  static int estimerCout(DateTime dateDebut) {
    final jours = DateTime.now().difference(dateDebut).inDays;
    final anneesPayantes = (jours / 365).ceil() - 1;
    return (anneesPayantes < 0 ? 0 : anneesPayantes) * 200;
  }

  /// Demande l'achat historique pour une date de début donnée — le prix
  /// (gratuit ≤ 1 an, 200 FCFA/année supplémentaire, D5) est calculé côté
  /// backend à partir de [dateDebut] (HistoriqueService.calculer_cout) et
  /// renvoyé dans la réponse, jamais codé en dur côté mobile.
  static Future<ResultatAchat> demanderAchat(
    String telephone,
    DateTime dateDebut,
  ) async {
    final deviceId = await LicenceService.getDeviceId();
    final dateDebutStr =
        '${dateDebut.year.toString().padLeft(4, '0')}-${dateDebut.month.toString().padLeft(2, '0')}-${dateDebut.day.toString().padLeft(2, '0')}';
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/historique/demander/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'telephone': telephone,
          'device_id': deviceId,
          'date_debut': dateDebutStr,
        }),
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode >= 400) {
        return ResultatAchat.erreur(data['erreur'] ?? 'Erreur inconnue');
      }

      if (data['statut'] == 'deja_active' || data['statut'] == 'active') {
        await HistoriqueStorage.sauvegarderToken(data['token']);
        return ResultatAchat.active(montant: (data['montant'] as num?)?.toInt() ?? 0);
      }

      return ResultatAchat.enAttente(
        montant: (data['montant'] as num?)?.toInt() ?? 0,
        message: data['message'] ?? 'Demande envoyée',
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

    // 2. Charger opérateurs + leurs patterns (moteur unique, partagé avec
    // le listener temps réel — SmsMatchingEngine)
    final operators = await db.query('operators', where: 'is_active = 1');
    if (operators.isEmpty) {
      return ResultatImport.erreur('Aucun opérateur configuré');
    }

    final opConfigs = <String, _OpConfig>{};
    for (final op in operators) {
      final opId = op['id'] as String;
      final sender = (op['sms_sender'] as String?) ?? '';
      if (sender.isEmpty) continue;

      final patterns = await SmsMatchingEngine.loadPatternsForOperator(db, opId);
      opConfigs[opId] = _OpConfig(sender: sender, patterns: patterns);
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

        // 5. Tester tous les patterns de l'opérateur — PAS de fallback
        // Seuls les SMS qui matchent un pattern configuré sont pris
        final smsMatch = SmsMatchingEngine.match(body, config.patterns);
        if (smsMatch == null) {
          ignores++;
          if (totalAnalyses % 20 == 0) onProgress(totalAnalyses, totalSms);
          continue;
        }
        final txType = smsMatch.transactionTypeCode;
        final extracted = smsMatch.extractedFields;

        // 6. Extraire le montant
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

        // 8. Calculer commission (fonction unique — CommissionCalculator)
        final commission = CommissionCalculator.compute(
          amount: amount,
          commissionTaux: smsMatch.commissionTaux,
        );

        // 9. Créer la transaction
        final txId = 'imp_${date.millisecondsSinceEpoch}_$crees';
        await db.insert('transactions', {
          'id': txId,
          'operator_id': opId,
          'transaction_type': txType,
          'transaction_type_id': smsMatch.transactionTypeId,
          'direction': smsMatch.direction,
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

}

class _OpConfig {
  final String sender;
  final List<Map<String, Object?>> patterns;

  _OpConfig({required this.sender, required this.patterns});
}

enum StatutAchat { enAttente, active, timeout }

class ResultatAchat {
  final bool succes;
  final bool dejaActive;
  final int montant;
  final String message;
  ResultatAchat.active({required this.montant})
      : succes = true,
        dejaActive = true,
        message = montant == 0
            ? 'Import historique activé gratuitement'
            : 'Import historique activé';
  ResultatAchat.enAttente({required this.montant, required this.message})
      : succes = false,
        dejaActive = false;
  ResultatAchat.erreur(this.message)
      : succes = false,
        dejaActive = false,
        montant = 0;
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
