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
  /// 0-100. 100 = match exact (regex structurée ou legacy, comportement
  /// historique). En dessous de 100, c'est un match flou (voir
  /// `SmsMatchingEngine._fuzzyScore`) — le pipeline SMS décide du seuil de
  /// confirmation (>=80 auto-créé, 60-79 nécessite confirmation manuelle).
  final int confidence;

  SmsMatch({
    required this.transactionTypeId,
    required this.transactionTypeCode,
    required this.typeLabel,
    required this.direction,
    required this.operatorTransactionTypeId,
    required this.commissionTaux,
    required this.extractedFields,
    this.confidence = 100,
  });

  /// Sous le seuil "haute confiance" (voir `SmsMatchingEngine.autoCreateMin`)
  /// — la transaction doit être créée en statut 'pending', pas 'completed'.
  bool get needsConfirmation => confidence < SmsMatchingEngine.autoCreateMin;
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

  /// En dessous de ce score flou (0-100), le SMS est ignoré — trop peu de
  /// ressemblance avec un pattern connu pour créer quoi que ce soit.
  static const minConfidence = 60;

  /// À partir de ce score, la transaction est créée directement
  /// ('completed'), comme un match exact. Entre [minConfidence] et ce seuil,
  /// elle est créée en 'pending' — l'agent confirme ou corrige le type
  /// depuis l'écran de transaction (déjà existant, réactivé pour ce cas).
  static const autoCreateMin = 80;

  /// Essaie chaque pattern par ordre de spécificité et retourne le premier
  /// qui matche exactement avec un montant extrait (confiance 100). Si
  /// aucun ne matche exactement, retombe sur un score de similarité flou
  /// entre le SMS et le texte littéral de chaque pattern structuré (D2) —
  /// robuste aux petites variations de formulation opérateur (espaces
  /// collés/séparés, ponctuation) qui cassent un match exact alors que le
  /// contenu est manifestement le même. En dessous de [minConfidence],
  /// aucun repli : ce n'est pas une transaction (comportement strict
  /// conservé).
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
      return _buildMatch(p, fields, confidence: 100);
    }

    return _fuzzyMatch(body, patterns);
  }

  /// Repli flou : uniquement sur les patterns structurés (les seuls que
  /// l'UI actuelle peut créer, D2) — les patterns legacy ont déjà leur
  /// propre tolérance via `_matchesLegacy` et n'ont pas de zones taguées
  /// exploitables pour un score littéral.
  static SmsMatch? _fuzzyMatch(String body, List<Map<String, Object?>> patterns) {
    Map<String, Object?>? bestPattern;
    var bestScore = 0;

    for (final p in patterns) {
      final taggedZonesJson = p['tagged_zones_json'] as String?;
      final rawExample = p['raw_example'] as String?;
      if (taggedZonesJson == null || taggedZonesJson.isEmpty) continue;
      if (rawExample == null || rawExample.isEmpty) continue;

      List<TaggedZone> zones;
      try {
        zones = SmsPatternBuilder.zonesFromJson(taggedZonesJson);
      } catch (_) {
        continue;
      }

      final score = _fuzzyScore(body, rawExample, zones);
      if (score > bestScore) {
        bestScore = score;
        bestPattern = p;
      }
    }

    if (bestPattern == null || bestScore < minConfidence) return null;

    // Extraction indépendante du contexte littéral (celui-ci a justement
    // échoué à matcher exactement) — mêmes heuristiques génériques que les
    // patterns legacy.
    final fields = SmsFieldExtractor.extractAll(body);
    if (!fields.containsKey('montant')) return null;

    return _buildMatch(bestPattern, fields, confidence: bestScore);
  }

  /// Score de similarité (0-100) entre un SMS et le texte littéral d'un
  /// pattern structuré. Comparé **mot par mot** (pas segment entier) : un
  /// segment littéral non tagué contient souvent un détail variable noyé
  /// dedans (ex: nom/numéro d'agent — voir `raw_example` réels) que le
  /// tagging n'a pas capturé ; exiger que le segment entier matche
  /// verbatim ferait perdre TOUT son poids à cause d'un seul mot différent,
  /// alors que le reste du segment est bien présent. Chaque mot est
  /// recherché comme sous-chaîne dans le SMS normalisé (espaces supprimés,
  /// donc insensible aux mots collés/séparés), pondéré par sa longueur pour
  /// qu'un mot très court/fréquent ("FCFA", "de") ne pèse pas autant qu'un
  /// mot long et discriminant ("retrait", "aupres").
  static int _fuzzyScore(String body, String rawExample, List<TaggedZone> zones) {
    final words = SmsPatternBuilder.literalChunks(rawExample, zones)
        .expand((chunk) => chunk.split(RegExp(r'\s+')))
        .map((w) => w.toLowerCase())
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.isEmpty) return 0;

    final normalizedBody = _normalize(body);
    var totalWeight = 0;
    var matchedWeight = 0;
    for (final word in words) {
      totalWeight += word.length;
      if (normalizedBody.contains(word)) {
        matchedWeight += word.length;
      }
    }
    if (totalWeight == 0) return 0;
    return ((matchedWeight / totalWeight) * 100).round();
  }

  static String _normalize(String s) => s.toLowerCase().replaceAll(RegExp(r'\s+'), '');

  static SmsMatch _buildMatch(
    Map<String, Object?> p,
    Map<String, String> fields, {
    required int confidence,
  }) {
    return SmsMatch(
      transactionTypeId: p['ott_transaction_type_id'] as String,
      transactionTypeCode: p['transaction_type'] as String,
      typeLabel: p['type_label'] as String? ?? p['transaction_type'] as String,
      direction: p['direction'] as String? ?? 'in',
      operatorTransactionTypeId: p['operator_transaction_type_id'] as String,
      commissionTaux: (p['ott_commission_taux'] as num?)?.toDouble() ?? 0,
      extractedFields: fields,
      confidence: confidence,
    );
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
