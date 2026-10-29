import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/categories/category_providers.dart';
import '../../core/onboarding/onboarding_state.dart';

/// Menu latéral : seulement ce qui sert au quotidien. Les onglets du bas
/// couvrent déjà l'essentiel ; ici, le reste de l'usage courant, puis
/// Paramètres et Aide. Les réglages techniques (opérateurs, modèles de SMS,
/// diagnostic) vivent dans Paramètres → Paramètres avancés.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAgence = ref.watch(accountTypeProvider).valueOrNull == 'agence';
    final toCategorize = isAgence ? 0 : (ref.watch(uncategorizedCountProvider).valueOrNull ?? 0);
    final theme = Theme.of(context);

    void open(String route) {
      Navigator.pop(context);
      context.push(route);
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 44,
                      height: 44,
                      errorBuilder: (_, _, _) => Icon(Icons.account_balance_wallet,
                          size: 44, color: theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('MoneyTracking',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        Text(isAgence ? 'Mon agence' : 'Mon argent, simplement',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.colorScheme.outlineVariant.withAlpha(110)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  if (isAgence) ...[
                    _Item(Icons.people_outline, 'Mes clients', () => open('/clients')),
                    _Item(Icons.account_balance_outlined, 'Caisse et float',
                        () => open('/settings/caisse')),
                    _Item(Icons.store_outlined, 'Mes agences',
                        () => open('/agences/mes-agences')),
                  ] else ...[
                    _Item(Icons.label_outline, 'Ranger mes dépenses',
                        () => open('/categorize'),
                        badge: toCategorize),
                    _Item(Icons.phone_android, 'Mes téléphones',
                        () => open('/telephones/mes-telephones')),
                  ],
                  Divider(height: 24, indent: 16, endIndent: 16,
                      color: theme.colorScheme.outlineVariant.withAlpha(110)),
                  _Item(Icons.settings_outlined, 'Paramètres', () => open('/settings')),
                  _Item(Icons.help_outline, 'Un SMS n\'a pas été détecté ?',
                      () => open('/settings/aide-detection')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  const _Item(this.icon, this.label, this.onTap, {this.badge = 0});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: badge > 0
            ? Badge(label: Text('$badge'), backgroundColor: Theme.of(context).colorScheme.primary)
            : null,
        onTap: onTap,
      );
}
