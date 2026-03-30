import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
      body: navigationShell,
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
