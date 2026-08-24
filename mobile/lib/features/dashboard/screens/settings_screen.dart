import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/onboarding/catalog_sync_service.dart';
import '../../../core/onboarding/onboarding_state.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_notifier.dart';

/// Provider pour le device ID
final deviceIdProvider = FutureProvider<String>((ref) async {
  final info = DeviceInfoPlugin();
  final android = await info.androidInfo;
  return android.id;
});

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
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.battery_charging_full, color: AppColors.accentColor),
                  title: const Text('Fonctionnement en arrière-plan'),
                  subtitle: const Text('Autoriser la détection même app fermée'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _demanderExemptionBatterie(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.sync, color: AppColors.primaryColor),
                  title: const Text('Resynchroniser le catalogue'),
                  subtitle: const Text('Récupère les corrections de patterns SMS'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _resynchroniserCatalogue(context, ref),
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

          // === Import Historique ===
          _sectionTitle(context, 'Import'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.history, color: AppColors.accentColor),
                  title: const Text('Import Historique SMS'),
                  subtitle: const Text('Importer les anciens SMS'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/historique/import'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // === Licence ===
          _sectionTitle(context, 'Licence'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.vpn_key, color: AppColors.primaryColor),
                  title: const Text('Ma Licence'),
                  subtitle: const Text('Statut et renouvellement'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/licence/statut'),
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
                  const SizedBox(height: 8),
                  Consumer(builder: (context, ref, _) {
                    final deviceId = ref.watch(deviceIdProvider);
                    return deviceId.when(
                      data: (id) => InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Device ID copié')),
                          );
                        },
                        child: Row(
                          children: [
                            const Icon(Icons.smartphone, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Device ID: $id',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontSize: 10,
                                      fontFamily: 'monospace',
                                    ),
                              ),
                            ),
                            const Icon(Icons.copy, size: 12, color: Colors.grey),
                          ],
                        ),
                      ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    );
                  }),
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

  /// Redemande le catalogue au serveur pour les opérateurs déjà importés —
  /// répare immédiatement une détection cassée par un pattern SMS mal tagué
  /// côté admin (CatalogSyncService.resyncOperators), sans attendre le
  /// prochain démarrage de l'app (qui le fait aussi automatiquement).
  Future<void> _resynchroniserCatalogue(BuildContext context, WidgetRef ref) async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Resynchronisation en cours...')),
    );
    try {
      final onboardingService = ref.read(onboardingStatusServiceProvider);
      final countryCode = await onboardingService.getCountryCode();
      final accountType = await onboardingService.getAccountType();
      final changed = await CatalogSyncService().resyncOperators(
        countryCode: countryCode,
        accountType: accountType,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            changed > 0
                ? '$changed pattern(s) SMS mis à jour'
                : 'Catalogue déjà à jour',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de resynchroniser - vérifiez votre connexion')),
      );
    }
  }

  /// Demande l'exemption d'optimisation batterie — nécessaire sur beaucoup
  /// d'appareils (Xiaomi, Tecno, Infinix, Samsung...) pour que la détection
  /// SMS continue de fonctionner quand l'app est fermée. Toujours précédé
  /// d'une explication : jamais demandé silencieusement.
  Future<void> _demanderExemptionBatterie(BuildContext context) async {
    final statut = await Permission.ignoreBatteryOptimizations.status;
    if (statut.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Déjà autorisé - l\'app peut fonctionner en arrière-plan')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fonctionnement en arrière-plan'),
        content: const Text(
          'Pour que MoneyTracking détecte vos SMS même quand l\'app est '
          'fermée, Android doit être autorisé à ne pas la mettre en veille '
          'forcée. Sans ça, certains téléphones (Xiaomi, Tecno, Infinix, '
          'Samsung...) coupent la détection après quelques minutes.\n\n'
          'L\'écran suivant vient d\'Android - choisissez "Autoriser" ou '
          '"Ne pas optimiser".',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Plus tard')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuer')),
        ],
      ),
    );
    if (confirme != true) return;

    final resultat = await Permission.ignoreBatteryOptimizations.request();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          resultat.isGranted
              ? 'Autorisé - MoneyTracking peut fonctionner en arrière-plan'
              : 'Non autorisé - la détection pourrait s\'arrêter app fermée sur certains téléphones',
        ),
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
