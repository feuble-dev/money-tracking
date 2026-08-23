/// Modèle représentant un pattern SMS configuré.
///
/// `operatorTransactionTypeId` + `taggedZonesJson` + `regexGenerated` réel
/// (compilé via SmsPatternBuilder, jamais 'auto_detect') sont obligatoires
/// pour tout nouveau pattern — c'est ce qui empêche un pattern d'un type de
/// transaction de matcher accidentellement le SMS d'un autre type.
class SmsPatternModel {
  final String id;
  final String operatorId;
  final String transactionType; // code du type, ex: 'deposit', 'transfert'
  final String? operatorTransactionTypeId;
  final String? direction; // 'in' | 'out'
  final String? taggedZonesJson;
  final String source; // 'catalog' | 'catalog_overridden' | 'custom'
  final String? senderFilter;
  final String rawExample;
  final String patternJson;
  final String regexGenerated;
  final DateTime createdAt;

  SmsPatternModel({
    required this.id,
    required this.operatorId,
    required this.transactionType,
    this.operatorTransactionTypeId,
    this.direction,
    this.taggedZonesJson,
    this.source = 'custom',
    this.senderFilter,
    required this.rawExample,
    required this.patternJson,
    required this.regexGenerated,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'operator_id': operatorId,
        'transaction_type': transactionType,
        'operator_transaction_type_id': operatorTransactionTypeId,
        'direction': direction,
        'tagged_zones_json': taggedZonesJson,
        'source': source,
        'sender_filter': senderFilter,
        'raw_example': rawExample,
        'pattern_json': patternJson,
        'regex_generated': regexGenerated,
        'created_at': createdAt.toIso8601String(),
      };

  factory SmsPatternModel.fromMap(Map<String, dynamic> map) =>
      SmsPatternModel(
        id: map['id'] as String,
        operatorId: map['operator_id'] as String,
        transactionType: map['transaction_type'] as String,
        operatorTransactionTypeId: map['operator_transaction_type_id'] as String?,
        direction: map['direction'] as String?,
        taggedZonesJson: map['tagged_zones_json'] as String?,
        source: map['source'] as String? ?? 'custom',
        senderFilter: map['sender_filter'] as String?,
        rawExample: map['raw_example'] as String,
        patternJson: map['pattern_json'] as String,
        regexGenerated: map['regex_generated'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
