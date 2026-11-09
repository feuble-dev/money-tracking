import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/licence/licence_storage.dart';
import '../../core/onboarding/onboarding_state.dart';
import '../../core/theme/app_colors.dart';
import '../../features/transactions/providers/transaction_provider.dart';
import 'app_drawer.dart';

/// Clé globale pour ouvrir le drawer depuis n'importe quel écran enfant
final mainScaffoldKey = GlobalKey<ScaffoldState>();

/// Jours de licence restants (bannière d'expiration). Relu à chaque
/// ouverture du shell, pas à chaque reconstruction.
final licenceDaysLeftProvider =
    FutureProvider<int>((ref) => LicenceStorage.getJoursRestants());

/// Branches du shell, dans l'ordre déclaré par le router.
abstract final class ShellBranch {
  static const dashboard = 0;
  static const transactions = 1;
  static const commissions = 2;
  static const money = 3;
  static const budget = 4;
}

class _Tab {
  final int branch;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool badge;
  const _Tab(this.branch, this.icon, this.selectedIcon, this.label,
      {this.badge = false});
}

/// Agence : activité d'agent (transactions, commissions).
const _agenceTabs = [
  _Tab(ShellBranch.dashboard, Icons.dashboard_outlined, Icons.dashboard,
      'Accueil'),
  _Tab(ShellBranch.transactions, Icons.receipt_long_outlined,
      Icons.receipt_long, 'Transactions',
      badge: true),
  _Tab(ShellBranch.commissions, Icons.monetization_on_outlined,
      Icons.monetization_on, 'Commissions'),
];

/// Particulier : tout son argent, ses mouvements, son budget (D7/D20).
const _particulierTabs = [
  _Tab(ShellBranch.dashboard, Icons.insights_outlined, Icons.insights,
      'Accueil'),
  _Tab(ShellBranch.money, Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet, 'Mon argent'),
  _Tab(ShellBranch.transactions, Icons.receipt_long_outlined,
      Icons.receipt_long, 'Mobile Money',
      badge: true),
  _Tab(ShellBranch.budget, Icons.savings_outlined, Icons.savings, 'Budget'),
];

/// Shell à onglets ; les onglets dépendent du type de compte.
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingCountProvider);
    final isParticulier =
        ref.watch(accountTypeProvider).valueOrNull == 'particulier';
    final tabs = isParticulier ? _particulierTabs : _agenceTabs;
    final selected = tabs
        .indexWhere((t) => t.branch == navigationShell.currentIndex)
        .clamp(0, tabs.length - 1);

    return Scaffold(
      key: mainScaffoldKey,
      drawer: const AppDrawer(),
      body: Column(
        children: [
          if (!isParticulier) const _LicenceBanner(),
          Expanded(child: navigationShell),
        ],
      ),
      // Agence : raccourci vers les transactions à confirmer. Le Particulier
      // a son propre bouton « Ajouter » sur l'accueil.
      floatingActionButton: !isParticulier &&
              pendingCount > 0 &&
              navigationShell.currentIndex == ShellBranch.dashboard
          ? FloatingActionButton.extended(
              heroTag: 'pending_fab',
              onPressed: () => context.push('/notifications'),
              backgroundColor: AppColors.accentColor,
              icon: const Icon(Icons.notification_important),
              label: Text('$pendingCount en attente'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (i) {
          final branch = tabs[i].branch;
          navigationShell.goBranch(
            branch,
            initialLocation: branch == navigationShell.currentIndex,
          );
        },
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: _badged(Icon(t.icon), t.badge ? pendingCount : 0),
              selectedIcon:
                  _badged(Icon(t.selectedIcon), t.badge ? pendingCount : 0),
              label: t.label,
            ),
        ],
      ),
    );
  }

  static Widget _badged(Widget icon, int count) => Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        backgroundColor: AppColors.accentColor,
        child: icon,
      );
}

/// Bannière d'expiration (comptes Agence ; un Particulier est gratuit).
class _LicenceBanner extends ConsumerWidget {
  const _LicenceBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jours = ref.watch(licenceDaysLeftProvider).valueOrNull ?? 999;
    if (jours > 7) return const SizedBox.shrink();
    return Material(
      color: jours > 0 ? Colors.orange.shade700 : Colors.red.shade700,
      child: SafeArea(
        bottom: false,
        child: InkWell(
          onTap: () => context.push('/licence/statut'),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    jours > 0
                        ? 'Licence expire dans $jours jours'
                        : 'Licence expirée',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
                const Text(
                  'Renouveler',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
