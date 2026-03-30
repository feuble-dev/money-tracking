/// Modèle représentant une transaction
class TransactionModel {
  final String id;
  final String operatorId;
  final String? clientId;
  final String transactionType; // 'deposit' | 'withdrawal'
  final double amount;
  final double commission;
  final String clientPhone;
  final String? clientName;
  final String? clientCnib;
  final String? clientBirthDate;
  final String? operatorTransactionId;
  final String? operatorReference;
  final String status; // 'pending' | 'completed' | 'rejected'
  final String source; // 'manual' | 'sms_auto'
  final String? smsRaw;
  final DateTime createdAt;

  // Champs joints (non stockés en base)
  final String? operatorName;

  TransactionModel({
    required this.id,
    required this.operatorId,
    this.clientId,
    required this.transactionType,
    required this.amount,
    this.commission = 0,
    required this.clientPhone,
    this.clientName,
    this.clientCnib,
    this.clientBirthDate,
    this.operatorTransactionId,
    this.operatorReference,
    this.status = 'completed',
    this.source = 'manual',
    this.smsRaw,
    DateTime? createdAt,
    this.operatorName,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isDeposit => transactionType == 'deposit';
  bool get isPending => status == 'pending';

  Map<String, dynamic> toMap() => {
        'id': id,
        'operator_id': operatorId,
        'client_id': clientId,
        'transaction_type': transactionType,
        'amount': amount,
        'commission': commission,
        'client_phone': clientPhone,
        'client_name': clientName,
        'client_cnib': clientCnib,
        'client_birth_date': clientBirthDate,
        'operator_transaction_id': operatorTransactionId,
        'operator_reference': operatorReference,
        'status': status,
        'source': source,
        'sms_raw': smsRaw,
        'created_at': createdAt.toIso8601String(),
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) =>
      TransactionModel(
        id: map['id'] as String,
        operatorId: map['operator_id'] as String,
        clientId: map['client_id'] as String?,
        transactionType: map['transaction_type'] as String,
        amount: (map['amount'] as num).toDouble(),
        commission: (map['commission'] as num?)?.toDouble() ?? 0,
        clientPhone: map['client_phone'] as String,
        clientName: map['client_name'] as String?,
        clientCnib: map['client_cnib'] as String?,
        clientBirthDate: map['client_birth_date'] as String?,
        operatorTransactionId: map['operator_transaction_id'] as String?,
        operatorReference: map['operator_reference'] as String?,
        status: map['status'] as String? ?? 'completed',
        source: map['source'] as String? ?? 'manual',
        smsRaw: map['sms_raw'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        operatorName: map['operator_name'] as String?,
      );

  TransactionModel copyWith({
    String? clientId,
    String? clientName,
    String? clientCnib,
    String? clientBirthDate,
    String? clientPhone,
    String? status,
    double? commission,
  }) =>
      TransactionModel(
        id: id,
        operatorId: operatorId,
        clientId: clientId ?? this.clientId,
        transactionType: transactionType,
        amount: amount,
        commission: commission ?? this.commission,
        clientPhone: clientPhone ?? this.clientPhone,
        clientName: clientName ?? this.clientName,
        clientCnib: clientCnib ?? this.clientCnib,
        clientBirthDate: clientBirthDate ?? this.clientBirthDate,
        operatorTransactionId: operatorTransactionId,
        operatorReference: operatorReference,
        status: status ?? this.status,
        source: source,
        smsRaw: smsRaw,
        createdAt: createdAt,
        operatorName: operatorName,
      );
}
