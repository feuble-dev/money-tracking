import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'sms_field_extractor.dart';
import 'sms_pattern_builder.dart';

/// Résultat d'un match : le type de transaction effectif (générique, pas
/// limité à dépôt/retrait), son sens (D1) et les champs extraits.
class SmsMatch {
  final String transactionTypeId;
  final String transactionTypeCode;
  final String typeLabel;
  final String direction; // 'in' | 'out'
  final String operatorTransactionTypeId;
  final double commissionTaux;
  final Map<String, String> extractedFields;

  SmsMatch({
    required this.transactionTypeId,
    required this.transactionTypeCode,
    required this.typeLabel,
    required this.direction,
    required this.operatorTransactionTypeId,
    required this.commissionTaux,
    required this.extractedFields,
  });
}

/// Moteur de matching unique, partagé entre le listener temps réel
/// (sms_listener.dart) et l'import historique (historique_service.dart) —
/// remplace les deux implémentations dupliquées et incohérentes (l'une
/// exigeait UNE phrase discriminante, l'autre TOUTES) par un comportement
/// unique, itérant sur N types de transaction au lieu de 2 buckets fixes.
class SmsMatchingEngine {
  /// Charge, pour un opérateur donné, tous ses patterns joints à leur type
  /// (commission, direction déjà résolue — D1). INNER JOIN : un pattern
  /// orphelin (operator_transaction_type_id manquant) est ignoré plutôt que
  /// de faire planter le matching.
  static Future<List<Map<String, Object?>>> loadPatternsForOperator(
    Database db,
    String operatorId,
  ) async {
    return db.rawQuery('''
      SELECT sp.*,
             ott.commission_taux as ott_commission_taux,
             ott.transaction_type_id as ott_transaction_type_id,
             tt.label as type_label
      FROM sms_patterns sp
      JOIN operator_transaction_types ott ON sp.operator_transaction_type_id = ott.id
      JOIN transaction_types tt ON ott.transaction_type_id = tt.id
      WHERE sp.operator_id = ? AND ott.is_active = 1
    ''', [operatorId]);
  }

  /// Essaie chaque pattern par ordre de spécificité et retourne le premier
  /// qui matche avec un montant extrait. Aucun fallback implicite : si rien
  /// ne matche, ce n'est pas une transaction (comportement strict conservé).
  static SmsMatch? match(String body, List<Map<String, Object?>> patterns) {
    for (final p in _sortBySpecificity(patterns)) {
      final taggedZonesJson = p['tagged_zones_json'] as String?;
      Map<String, String>? fields;

      if (taggedZonesJson != null && taggedZonesJson.isNotEmpty) {
        // Pattern structuré (catalogue admin ou tagging local, D2) : regex
        // réelle compilée à l'import/à la configuration.
        final regex = p['regex_generated'] as String?;
        if (regex == null || regex.isEmpty) continue;
        fields = SmsPatternBuilder.parseSms(body, regex);
      } else {
        // Pattern legacy ('auto_detect', pré-catalogue) : comportement
        // historique conservé pour ne pas casser la détection déjà en
        // place chez les agents actuels.
        if (!_matchesLegacy(body, p['raw_example'] as String? ?? '')) {
          continue;
        }
        fields = SmsFieldExtractor.extractAll(body);
      }

      if (fields == null || !fields.containsKey('montant')) continue;

      return SmsMatch(
        transactionTypeId: p['ott_transaction_type_id'] as String,
        transactionTypeCode: p['transaction_type'] as String,
        typeLabel: p['type_label'] as String? ?? p['transaction_type'] as String,
        direction: p['direction'] as String? ?? 'in',
        operatorTransactionTypeId: p['operator_transaction_type_id'] as String,
        commissionTaux: (p['ott_commission_taux'] as num?)?.toDouble() ?? 0,
        extractedFields: fields,
      );
    }
    return null;
  }

  /// Patterns structurés (regex réelle) avant les patterns legacy ; parmi
  /// les structurés, plus de zones taguées = plus spécifique = prioritaire.
  static List<Map<String, Object?>> _sortBySpecificity(
    List<Map<String, Object?>> patterns,
  ) {
    final sorted = List<Map<String, Object?>>.from(patterns);
    sorted.sort((a, b) {
      final aZones = _zoneCount(a);
      final bZones = _zoneCount(b);
      final aStructured = aZones != null;
      final bStructured = bZones != null;
      if (aStructured != bStructured) return aStructured ? -1 : 1;
      if (aStructured && bStructured) return bZones.compareTo(aZones);
      return 0;
    });
    return sorted;
  }

  static int? _zoneCount(Map<String, Object?> pattern) {
    final json = pattern['tagged_zones_json'] as String?;
    if (json == null || json.isEmpty) return null;
    try {
      return (jsonDecode(json) as List).length;
    } catch (_) {
      return null;
    }
  }

  /// Règle stricte retenue comme référence unique (ex-comportement de
  /// l'import historique) : TOUTES les phrases discriminantes de l'exemple
  /// doivent être présentes dans le SMS candidat. Le listener temps réel
  /// exigeait auparavant qu'UNE SEULE le soit — plus permissif, donc plus
  /// exposé aux faux positifs ; on retient la version stricte pour les deux
  /// pipelines désormais.
  static bool _matchesLegacy(String body, String rawExample) {
    if (rawExample.length <= 20) return false;
    final phrases = _extractKeyPhrases(rawExample);
    if (phrases.isEmpty) return false;
    final bodyLower = body.toLowerCase();
    return phrases.every((phrase) => bodyLower.contains(phrase.toLowerCase()));
  }

  static const _discriminants = [
    'vous avez transfere',
    'vous avez envoye',
    'depot de',
    'transfert de',
    'envoye a',
    'transfere a',
    'vous avez recu',
    'retrait de',
    'a retire',
    'received from',
    'vous a envoye',
    'credit de',
  ];

  static List<String> _extractKeyPhrases(String example) {
    final lower = example.toLowerCase();
    final phrases = <String>[];
    for (final d in _discriminants) {
      if (lower.contains(d)) phrases.add(d);
    }
    if (phrases.isEmpty) {
      final fcfaMatch = RegExp(
        r'([a-zà-ÿ\s]{10,})\d[\d\s.,]*\s*fcfa',
        caseSensitive: false,
      ).firstMatch(lower);
      if (fcfaMatch != null) {
        final prefix = fcfaMatch.group(1)!.trim();
        if (prefix.length >= 8) phrases.add(prefix);
      }
    }
    return phrases;
  }
}
