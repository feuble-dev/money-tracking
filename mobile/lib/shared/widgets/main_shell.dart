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

/// Shell avec 3 onglets : Dashboard, Transactions, puis Commissions (Agence)
/// ou Budget (Particulier, D7 — pas de notion de commission ; le 3ᵉ onglet
/// ouvre l'écran Budget/motifs). Clients déplacé dans le sidebar.
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingCountProvider);
    // Commissions n'a pas de sens pour un compte Particulier (D7) — masqué
    // du shell (le router bloque aussi l'accès direct à /commissions).
    final accountType = ref.watch(accountTypeProvider).valueOrNull ?? 'agence';
    final showCommissions = accountType != 'particulier';
    final currentIndex = showCommissions
        ? navigationShell.currentIndex
        : navigationShell.currentIndex.clamp(0, 1);

    return Scaffold(
      key: mainScaffoldKey,
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Bannière licence expiration — un compte Particulier n'a aucun
          // flux payant, la notion même de licence lui est invisible.
          if (accountType != 'particulier')
            FutureBuilder<int>(
              future: LicenceStorage.getJoursRestants(),
              builder: (context, snapshot) {
                final jours = snapshot.data ?? 999;
                if (jours > 7) return const SizedBox.shrink();

                return Container(
                  width: double.infinity,
                  color: jours > 0
                      ? Colors.orange.shade700
                      : Colors.red.shade700,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Row(
                      children: [
                        const Icon(Icons.warning,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            jours > 0
                                ? 'Licence expire dans $jours jours'
                                : 'Licence expirée',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/licence/statut'),
                          child: const Text(
                            'Renouveler',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          // Contenu principal
          Expanded(child: navigationShell),
        ],
      ),
      floatingActionButton: pendingCount > 0 && navigationShell.currentIndex == 0
          ? FloatingActionButton.extended(
              heroTag: 'pending_fab',
              onPressed: () => context.push('/notifications'),
              backgroundColor: AppColors.accentColor,
              icon: const Icon(Icons.notification_important),
              label: Text('$pendingCount en attente'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          // Particulier : le 3e onglet n'est pas une branche du shell (pas
          // de notion de commission, D7) — il ouvre l'écran Budget/motifs.
          if (!showCommissions && index == 2) {
            context.push('/budget');
            return;
          }
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text(pendingCount.toString()),
              backgroundColor: AppColors.accentColor,
              child: const Icon(Icons.receipt_long_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: pendingCount > 0,
              label: Text(pendingCount.toString()),
              backgroundColor: AppColors.accentColor,
              child: const Icon(Icons.receipt_long),
            ),
            label: 'Transactions',
          ),
          if (showCommissions)
            const NavigationDestination(
              icon: Icon(Icons.monetization_on_outlined),
              selectedIcon: Icon(Icons.monetization_on),
              label: 'Commissions',
            )
          else
            const NavigationDestination(
              icon: Icon(Icons.savings_outlined),
              selectedIcon: Icon(Icons.savings),
              label: 'Budget',
            ),
        ],
      ),
    );
  }
}
