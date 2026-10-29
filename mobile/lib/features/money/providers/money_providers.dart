import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/account_ref.dart';
import '../../../core/money/money_repository.dart';
import '../../../core/money/movement.dart';
import '../../../core/money/wallet.dart';
import '../../caisse/providers/caisse_provider.dart';
import '../../categories/providers/categorize_provider.dart';
import '../../dashboard/providers/particulier_dashboard_provider.dart';
import '../../operators/providers/operator_provider.dart';

/// Un compte tel qu'affiché dans « Mon argent » : compte manuel ou
/// portefeuille Mobile Money, même présentation.
@immutable
class MoneyAccount {
  final AccountRef ref;
  final String name;
  final String? emoji; // compte manuel
  final String? logoPath; // Mobile Money
  final Color color;

  /// `null` : solde inconnu (Mobile Money sans aucun SMS annonçant un solde).
  final double? balance;
  final Wallet? wallet;

  const MoneyAccount({
    required this.ref,
    required this.name,
    required this.color,
    this.emoji,
    this.logoPath,
    this.balance,
    this.wallet,
  });

  bool get isMobileMoney => ref.isMobileMoney;
}

const _momoColor = Color(0xFFF08C00);

/// Comptes tenus à la main, avec leur solde calculé.
final walletsProvider = FutureProvider<List<Wallet>>((ref) {
  return MoneyRepository.wallets();
});

/// Tous les comptes : Mobile Money (solde annoncé par le dernier SMS) puis
/// comptes manuels.
final moneyAccountsProvider = Provider<AsyncValue<List<MoneyAccount>>>((ref) {
  final wallets = ref.watch(walletsProvider);
  final operators = ref.watch(operatorsProvider);
  final caisses = ref.watch(caissesProvider);
  if (wallets.isLoading || operators.isLoading || caisses.isLoading) {
    return const AsyncValue.loading();
  }
  final soldes = {
    for (final c in caisses.valueOrNull ?? const <CaisseModel>[])
      if (c.operatorId != null) c.operatorId!: c.soldeActuel,
  };
  return AsyncValue.data([
    for (final op in operators.valueOrNull ?? const [])
      if (op.isActive)
        MoneyAccount(
          ref: AccountRef.momo(op.id),
          name: op.name,
          logoPath: op.logoPath,
          color: _momoColor,
          balance: soldes[op.id],
        ),
    for (final w in wallets.valueOrNull ?? const <Wallet>[])
      MoneyAccount(
        ref: w.ref,
        name: w.name,
        emoji: w.icon,
        color: w.color,
        balance: w.balance,
        wallet: w,
      ),
  ]);
});

/// Recherche rapide d'un compte par sa référence (nom/icône dans les listes).
final moneyAccountsByRefProvider = Provider<Map<AccountRef, MoneyAccount>>(
  (ref) => {
    for (final a in ref.watch(moneyAccountsProvider).valueOrNull ?? const [])
      a.ref: a,
  },
);

/// Total de tout l'argent connu (soldes inconnus ignorés).
final netWorthProvider = Provider<double>((ref) {
  final accounts = ref.watch(moneyAccountsProvider).valueOrNull ?? const [];
  return accounts.fold(0.0, (s, a) => s + (a.balance ?? 0));
});

/// Fil des mouvements ; `null` = tous les comptes.
final movementsProvider =
    FutureProvider.family<List<Movement>, AccountRef?>((ref, account) {
  return MoneyRepository.movements(account: account, limit: 80);
});

/// Après toute saisie/modification : soldes, fil, statistiques et budget.
void invalidateMoney(WidgetRef ref) {
  ref.invalidate(walletsProvider);
  ref.invalidate(movementsProvider);
  ref.invalidate(particulierDashboardProvider);
  ref.invalidate(monthlySpendByCategoryProvider);
  ref.invalidate(uncategorizedTransactionsProvider);
}
