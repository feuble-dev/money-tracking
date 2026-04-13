import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/licence/licence_storage.dart';
import '../../core/theme/app_colors.dart';
import '../../features/transactions/providers/transaction_provider.dart';
import 'app_drawer.dart';

/// Clé globale pour ouvrir le drawer depuis n'importe quel écran enfant
final mainScaffoldKey = GlobalKey<ScaffoldState>();

/// Shell avec 3 onglets : Dashboard, Transactions, Commissions
/// Clients déplacé dans le sidebar
class MainShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingCount = ref.watch(pendingCountProvider);

    return Scaffold(
      key: mainScaffoldKey,
      drawer: const AppDrawer(),
      body: Column(
        children: [
          // Bannière licence expiration
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
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
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
          const NavigationDestination(
            icon: Icon(Icons.monetization_on_outlined),
            selectedIcon: Icon(Icons.monetization_on),
            label: 'Commissions',
          ),
        ],
      ),
    );
  }
}
