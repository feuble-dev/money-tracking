import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_notifier.dart';

/// Écran des paramètres (accessible via l'icône engrenage dans l'AppBar)
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // === Thème ===
          _sectionTitle(context, 'Apparence'),
          Card(
            child: SwitchListTile(
              title: const Text('Mode sombre'),
              subtitle:
                  Text(isDark ? 'Thème sombre activé' : 'Thème clair activé'),
              value: isDark,
              onChanged: (_) {
                ref.read(themeModeProvider.notifier).toggleTheme();
              },
              secondary: Icon(
                isDark ? Icons.dark_mode : Icons.light_mode,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // === Gestion caisse ===
          _sectionTitle(context, 'Gestion'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.account_balance_wallet,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Gestion de la caisse'),
                  subtitle: const Text('Soldes, rechargements, alertes'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/caisse'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // === Diagnostic ===
          _sectionTitle(context, 'Diagnostic'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.sms, color: AppColors.accentColor),
                  title: const Text('Journal SMS'),
                  subtitle: const Text('Voir les SMS reçus et leur statut'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/sms-journal'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bug_report, color: Colors.orange),
                  title: const Text('Test détection SMS'),
                  subtitle: const Text('Vérifier si les SMS sont captés'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/sms-test'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // === Données ===
          _sectionTitle(context, 'Données'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: const Text('Export PDF'),
                  subtitle: const Text('Rapport transactions'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/export/pdf'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.table_chart, color: Colors.green),
                  title: const Text('Export CSV'),
                  subtitle: const Text('Données pour Excel'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/export/csv'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.backup,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Sauvegarde'),
                  subtitle: const Text('Sauvegarder la base de données'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/backup'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.restore, color: AppColors.accentColor),
                  title: const Text('Restauration'),
                  subtitle: const Text('Restaurer depuis une sauvegarde'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/settings/restore'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // === À propos ===
          _sectionTitle(context, 'À propos'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/icon.png',
                          width: 36,
                          height: 36,
                          errorBuilder: (_, _, _) => Icon(
                              Icons.phone_android,
                              color: Theme.of(context).colorScheme.primary),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'MoneyTracking',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Application de gestion et d\'automatisation de transactions Mobile Money',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Version 1.0.0',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'FEUBLE-TechBuilder © 2026',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
