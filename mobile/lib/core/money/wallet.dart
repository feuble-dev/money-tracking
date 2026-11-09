import 'package:flutter/material.dart';

import 'account_ref.dart';

/// Nature d'un compte tenu à la main.
enum WalletKind {
  cash('Espèces', '💵', '#2F9E44'),
  bank('Banque', '🏦', '#1971C2'),
  savings('Épargne / Tontine', '🐷', '#E8590C'),
  other('Autre', '👛', '#7048E8');

  final String label;
  final String defaultIcon;
  final String defaultColor;
  const WalletKind(this.label, this.defaultIcon, this.defaultColor);

  static WalletKind parse(String? v) =>
      WalletKind.values.firstWhere((k) => k.name == v, orElse: () => other);
}

/// Compte tenu à la main par le Particulier. [balance] est calculé par le
/// dépôt (solde initial + opérations), jamais stocké.
@immutable
class Wallet {
  final String id;
  final String name;
  final WalletKind kind;
  final String icon;
  final String colorHex;
  final double initialBalance;
  final int sortOrder;
  final bool isArchived;
  final double balance;

  const Wallet({
    required this.id,
    required this.name,
    required this.kind,
    required this.icon,
    required this.colorHex,
    this.initialBalance = 0,
    this.sortOrder = 0,
    this.isArchived = false,
    this.balance = 0,
  });

  AccountRef get ref => AccountRef.wallet(id);

  Color get color =>
      Color(int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16));

  factory Wallet.fromMap(Map<String, Object?> m) => Wallet(
        id: m['id'] as String,
        name: m['name'] as String,
        kind: WalletKind.parse(m['kind'] as String?),
        icon: m['icon'] as String? ?? '👛',
        colorHex: m['color'] as String? ?? '#7048E8',
        initialBalance: (m['initial_balance'] as num?)?.toDouble() ?? 0,
        sortOrder: (m['sort_order'] as num?)?.toInt() ?? 0,
        isArchived: (m['is_archived'] as num? ?? 0) == 1,
        balance: (m['balance'] as num?)?.toDouble() ??
            (m['initial_balance'] as num?)?.toDouble() ??
            0,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'icon': icon,
        'color': colorHex,
        'initial_balance': initialBalance,
        'sort_order': sortOrder,
        'is_archived': isArchived ? 1 : 0,
      };
}
