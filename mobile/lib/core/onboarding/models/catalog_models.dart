/// Modèles de désérialisation du catalogue backend (pays/opérateurs/types/
/// patterns). Ne compile jamais de regex ici (D2) — seul `tagged_zones` est
/// transporté, la compilation se fait localement via SmsPatternBuilder au
/// moment de l'import (CatalogSyncService).
class CatalogCountry {
  final int id;
  final String code;
  final String name;
  final String dialCode;

  CatalogCountry({
    required this.id,
    required this.code,
    required this.name,
    required this.dialCode,
  });

  factory CatalogCountry.fromJson(Map<String, dynamic> json) => CatalogCountry(
        id: json['id'] as int,
        code: json['code'] as String,
        name: json['name'] as String,
        dialCode: json['dial_code'] as String,
      );
}

class CatalogSmsPattern {
  final int id;
  final String rawExample;
  final List<Map<String, dynamic>> taggedZones;
  final String direction; // 'in' | 'out' — déjà résolu par le backend (D1)

  CatalogSmsPattern({
    required this.id,
    required this.rawExample,
    required this.taggedZones,
    required this.direction,
  });

  factory CatalogSmsPattern.fromJson(Map<String, dynamic> json) =>
      CatalogSmsPattern(
        id: json['id'] as int,
        rawExample: json['raw_example'] as String,
        taggedZones: (json['tagged_zones'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        direction: json['direction'] as String,
      );
}

/// Correspond à un OperatorTransactionType côté backend : le type + les
/// attributs propres à cet opérateur (USSD, commission) + ses patterns.
class CatalogTransactionType {
  final int id;
  final String code;
  final String label;
  final String defaultDirection;
  final String ussdCode;
  final double commissionTaux;
  final List<CatalogSmsPattern> smsPatterns;

  CatalogTransactionType({
    required this.id,
    required this.code,
    required this.label,
    required this.defaultDirection,
    required this.ussdCode,
    required this.commissionTaux,
    required this.smsPatterns,
  });

  factory CatalogTransactionType.fromJson(Map<String, dynamic> json) =>
      CatalogTransactionType(
        id: json['id'] as int,
        code: json['code'] as String,
        label: json['label'] as String,
        defaultDirection: json['default_direction'] as String,
        ussdCode: json['ussd_code'] as String? ?? '',
        commissionTaux:
            double.tryParse(json['commission_taux'].toString()) ?? 0,
        smsPatterns: (json['sms_patterns'] as List)
            .map((e) =>
                CatalogSmsPattern.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CatalogOperator {
  final int id;
  final String name;
  final String? logoUrl;
  final String smsSender;
  final List<CatalogTransactionType> transactionTypes;

  CatalogOperator({
    required this.id,
    required this.name,
    this.logoUrl,
    required this.smsSender,
    required this.transactionTypes,
  });

  factory CatalogOperator.fromJson(Map<String, dynamic> json) =>
      CatalogOperator(
        id: json['id'] as int,
        name: json['name'] as String,
        logoUrl: json['logo'] as String?,
        smsSender: json['sms_sender'] as String? ?? '',
        transactionTypes: (json['transaction_types'] as List)
            .map((e) => CatalogTransactionType.fromJson(
                e as Map<String, dynamic>))
            .toList(),
      );
}
