/// Modèle représentant un opérateur Mobile Money
class OperatorModel {
  final String id;
  final String name;
  final String? logoPath;
  final String? accountNumber;
  final String? agentNumber;
  final String? smsSender; // Ex: "OrangeMoney", "MOOV-BF"
  final String? ussdDepositTemplate;
  final String? ussdWithdrawTemplate;
  final bool isActive;
  final double tauxCommissionDepot;
  final double tauxCommissionRetrait;
  final DateTime createdAt;

  OperatorModel({
    required this.id,
    required this.name,
    this.logoPath,
    this.accountNumber,
    this.agentNumber,
    this.smsSender,
    this.ussdDepositTemplate,
    this.ussdWithdrawTemplate,
    this.isActive = true,
    this.tauxCommissionDepot = 0,
    this.tauxCommissionRetrait = 0,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'logo_path': logoPath,
        'account_number': accountNumber,
        'agent_number': agentNumber,
        'sms_sender': smsSender,
        'ussd_deposit_template': ussdDepositTemplate,
        'ussd_withdraw_template': ussdWithdrawTemplate,
        'is_active': isActive ? 1 : 0,
        'taux_commission_depot': tauxCommissionDepot,
        'taux_commission_retrait': tauxCommissionRetrait,
        'created_at': createdAt.toIso8601String(),
      };

  factory OperatorModel.fromMap(Map<String, dynamic> map) => OperatorModel(
        id: map['id'] as String,
        name: map['name'] as String,
        logoPath: map['logo_path'] as String?,
        accountNumber: map['account_number'] as String?,
        agentNumber: map['agent_number'] as String?,
        smsSender: map['sms_sender'] as String?,
        ussdDepositTemplate: map['ussd_deposit_template'] as String?,
        ussdWithdrawTemplate: map['ussd_withdraw_template'] as String?,
        isActive: (map['is_active'] as int?) == 1,
        tauxCommissionDepot: (map['taux_commission_depot'] as num?)?.toDouble() ?? 0,
        tauxCommissionRetrait: (map['taux_commission_retrait'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  OperatorModel copyWith({
    String? name,
    String? logoPath,
    String? accountNumber,
    String? agentNumber,
    String? smsSender,
    String? ussdDepositTemplate,
    String? ussdWithdrawTemplate,
    bool? isActive,
    double? tauxCommissionDepot,
    double? tauxCommissionRetrait,
  }) =>
      OperatorModel(
        id: id,
        name: name ?? this.name,
        logoPath: logoPath ?? this.logoPath,
        accountNumber: accountNumber ?? this.accountNumber,
        agentNumber: agentNumber ?? this.agentNumber,
        smsSender: smsSender ?? this.smsSender,
        ussdDepositTemplate: ussdDepositTemplate ?? this.ussdDepositTemplate,
        ussdWithdrawTemplate: ussdWithdrawTemplate ?? this.ussdWithdrawTemplate,
        isActive: isActive ?? this.isActive,
        tauxCommissionDepot: tauxCommissionDepot ?? this.tauxCommissionDepot,
        tauxCommissionRetrait: tauxCommissionRetrait ?? this.tauxCommissionRetrait,
        createdAt: createdAt,
      );
}
