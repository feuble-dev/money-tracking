/// Modèle représentant une transaction.
///
/// `transactionType` reste un code brut ('deposit', 'withdrawal', mais
/// aussi 'transfert', 'paiement_marchand', 'achat_credit'... depuis le
/// catalogue, D3) — ce n'est plus un binaire dépôt/retrait. `typeLabel`
/// (joint depuis `transaction_types.label`, jamais stocké sur la ligne)
/// porte le libellé réel à afficher, et `direction` ('in'|'out', D1)
/// remplace `isDeposit` pour toute logique de sens/couleur/icône.
class TransactionModel {
  final String id;
  final String operatorId;
  final String? clientId;
  final String transactionType;
  final String? transactionTypeId;
  final String? direction; // 'in' | 'out'
  final double amount;
  final double commission;
  final String clientPhone;
  final String? clientName;
  final String? clientCnib;
  final String? clientBirthDate;
  final String? operatorTransactionId;
  final String? operatorReference;
  final String status; // 'pending' | 'completed' | 'rejected' | 'cancelled'
  final String source; // 'manual' | 'sms_auto' | 'sms_import'
  final String? smsRaw;
  // 0-100, null si non-ambigu (manuel/import historique/match exact) —
  // score du matching flou (SmsMatchingEngine) quand status == 'pending'
  // à cause d'une formulation opérateur qui ne matchait pas exactement.
  final int? matchConfidence;
  final DateTime createdAt;

  // Champs joints (non stockés en base)
  final String? operatorName;
  final String? typeLabel;

  TransactionModel({
    required this.id,
    required this.operatorId,
    this.clientId,
    required this.transactionType,
    this.transactionTypeId,
    this.direction,
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
    this.matchConfidence,
    DateTime? createdAt,
    this.operatorName,
    this.typeLabel,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Repli legacy uniquement : `code == 'deposit'`. Ne plus utiliser pour
  /// l'affichage (voir [displayLabel]/[isEntrant]) — reste utile pour les
  /// tout premiers types seedés (deposit/withdrawal) et le code déjà
  /// dépendant de ce booléen (filtres historiques, exports).
  bool get isDeposit => transactionType == 'deposit';
  bool get isPending => status == 'pending';

  /// Sens réel (D1) — `direction` fait foi ; repli sur l'ancien binaire
  /// seulement pour d'éventuelles lignes très anciennes où la colonne
  /// serait restée nulle (ne devrait plus arriver depuis le backfill v9).
  bool get isEntrant => direction != null ? direction == 'in' : isDeposit;

  /// Libellé à afficher — le vrai nom du type catalogue (ex: "Transfert",
  /// "Paiement marchand") s'il a pu être joint, sinon repli binaire.
  String get displayLabel => typeLabel ?? (isDeposit ? 'Dépôt' : 'Retrait');

  Map<String, dynamic> toMap() => {
        'id': id,
        'operator_id': operatorId,
        'client_id': clientId,
        'transaction_type': transactionType,
        'transaction_type_id': transactionTypeId,
        'direction': direction,
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
        'match_confidence': matchConfidence,
        'created_at': createdAt.toIso8601String(),
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) =>
      TransactionModel(
        id: map['id'] as String,
        operatorId: map['operator_id'] as String,
        clientId: map['client_id'] as String?,
        transactionType: map['transaction_type'] as String,
        transactionTypeId: map['transaction_type_id'] as String?,
        direction: map['direction'] as String?,
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
        matchConfidence: (map['match_confidence'] as num?)?.toInt(),
        createdAt: DateTime.parse(map['created_at'] as String),
        operatorName: map['operator_name'] as String?,
        typeLabel: map['type_label'] as String?,
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
        transactionTypeId: transactionTypeId,
        direction: direction,
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
        typeLabel: typeLabel,
      );
}
