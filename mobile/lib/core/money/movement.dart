import 'package:flutter/foundation.dart';

import 'account_ref.dart';

/// Ligne du fil « Mes mouvements » : un revenu ou une dépense (Mobile Money
/// détecté par SMS, ou saisi à la main), ou un virement entre comptes.
@immutable
class Movement {
  final String id;

  /// 'momo' (transaction SMS) ou 'manual' (MoneyEntry).
  final String source;
  final AccountRef account;
  final AccountRef? counterAccount;

  /// 'in' | 'out' | 'transfer'
  final String direction;
  final double amount;
  final String? category;
  final String? label;
  final String? note;
  final DateTime occurredAt;

  const Movement({
    required this.id,
    required this.source,
    required this.account,
    required this.direction,
    required this.amount,
    required this.occurredAt,
    this.counterAccount,
    this.category,
    this.label,
    this.note,
  });

  bool get isManual => source == 'manual';
  bool get isTransfer => direction == 'transfer';
  bool get isIncome => direction == 'in';

  factory Movement.fromMap(Map<String, Object?> m) => Movement(
        id: m['id'] as String,
        source: m['source'] as String,
        account: AccountRef.tryParse(m['account'] as String?) ??
            const AccountRef.wallet('?'),
        counterAccount: AccountRef.tryParse(m['counter_account'] as String?),
        direction: m['direction'] as String,
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String?,
        label: m['label'] as String?,
        note: m['note'] as String?,
        occurredAt: DateTime.parse(m['occurred_at'] as String),
      );
}
