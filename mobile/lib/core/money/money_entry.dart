import 'package:flutter/foundation.dart';

import 'account_ref.dart';

enum EntryKind { income, expense, transfer }

/// Opération saisie à la main : revenu ou dépense sur un compte, ou
/// virement d'un compte vers un autre.
@immutable
class MoneyEntry {
  final String id;
  final EntryKind kind;

  /// Revenu/dépense : le compte concerné. Virement : le compte d'origine.
  final AccountRef account;

  /// Virement uniquement : le compte de destination.
  final AccountRef? counterAccount;
  final double amount;
  final String? category;

  /// « À qui / de qui / pour quoi » (ex. « Marché de Rood Woko »).
  final String? label;
  final String? note;
  final DateTime occurredAt;

  /// Transaction Mobile Money rattachée à un virement (ex. le SMS du retrait
  /// qui a alimenté les espèces) — voir MoneyRepository.
  final String? linkedTransactionId;

  const MoneyEntry({
    required this.id,
    required this.kind,
    required this.account,
    required this.amount,
    required this.occurredAt,
    this.counterAccount,
    this.category,
    this.label,
    this.note,
    this.linkedTransactionId,
  });

  /// Sens de l'opération vu depuis [ref] : +montant, -montant, ou 0 si ce
  /// compte n'est pas concerné.
  double signedFor(AccountRef ref) {
    switch (kind) {
      case EntryKind.income:
        return account == ref ? amount : 0;
      case EntryKind.expense:
        return account == ref ? -amount : 0;
      case EntryKind.transfer:
        if (account == ref) return -amount;
        if (counterAccount == ref) return amount;
        return 0;
    }
  }

  factory MoneyEntry.fromMap(Map<String, Object?> m) => MoneyEntry(
        id: m['id'] as String,
        kind: EntryKind.values.byName(m['kind'] as String),
        account: AccountRef.tryParse(m['account'] as String)!,
        counterAccount: AccountRef.tryParse(m['counter_account'] as String?),
        amount: (m['amount'] as num).toDouble(),
        category: m['category'] as String?,
        label: m['label'] as String?,
        note: m['note'] as String?,
        occurredAt: DateTime.parse(m['occurred_at'] as String),
        linkedTransactionId: m['linked_transaction_id'] as String?,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'kind': kind.name,
        'account': account.raw,
        'counter_account': counterAccount?.raw,
        'amount': amount,
        'category': category,
        'label': label,
        'note': note,
        'occurred_at': occurredAt.toIso8601String(),
        'linked_transaction_id': linkedTransactionId,
      };

  MoneyEntry copyWith({String? linkedTransactionId}) => MoneyEntry(
        id: id,
        kind: kind,
        account: account,
        counterAccount: counterAccount,
        amount: amount,
        category: category,
        label: label,
        note: note,
        occurredAt: occurredAt,
        linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
      );
}
