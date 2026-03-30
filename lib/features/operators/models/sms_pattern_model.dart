/// Modèle représentant un pattern SMS configuré
class SmsPatternModel {
  final String id;
  final String operatorId;
  final String transactionType; // 'deposit' | 'withdrawal'
  final String? senderFilter;
  final String rawExample;
  final String patternJson;
  final String regexGenerated;
  final DateTime createdAt;

  SmsPatternModel({
    required this.id,
    required this.operatorId,
    required this.transactionType,
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
        senderFilter: map['sender_filter'] as String?,
        rawExample: map['raw_example'] as String,
        patternJson: map['pattern_json'] as String,
        regexGenerated: map['regex_generated'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
