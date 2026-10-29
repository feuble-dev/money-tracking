import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/onboarding/onboarding_state.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../shared/widgets/settings_tiles.dart';
import '../../auth/providers/auth_provider.dart';

/// Paramètres : uniquement ce qu'un utilisateur ordinaire cherche, en mots
/// simples. Tout ce qui est technique (opérateurs, modèles de SMS, caisse,
/// diagnostic) est rangé dans « Paramètres avancés », à un geste de là.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAgence = ref.watch(accountTypeProvider).valueOrNull == 'agence';
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final bioAvailable = ref.watch(isBiometricAvailableProvider).valueOrNull ?? false;
    final bioEnabled = ref.watch(isBiometricEnabledProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (isAgence)
            SettingsSection(title: 'Licence', children: [
              SettingsTile(
                icon: Icons.verified_outlined,
                title: 'Ma licence',
                subtitle: 'Statut et renouvellement',
                onTap: () => context.push('/licence/statut'),
              ),
            ]),

          SettingsSection(title: 'Sécurité', children: [
            SettingsTile(
              icon: Icons.pin_outlined,
              title: 'Changer mon code PIN',
              onTap: () => context.push('/security/change-pin'),
            ),
            if (bioAvailable)
              SettingsTile.toggle(
                icon: Icons.fingerprint,
                title: 'Déverrouiller avec mon empreinte',
                value: bioEnabled,
                onChanged: (v) async {
                  await ref.read(biometricServiceProvider).setEnabled(v);
                  ref.invalidate(isBiometricEnabledProvider);
                },
              ),
            SettingsTile(
              icon: Icons.timer_outlined,
              title: 'Verrouillage automatique',
              subtitle: 'Après combien de temps l\'app se verrouille',
              onTap: () => context.push('/security/lock-timeout'),
            ),
          ]),

          SettingsSection(title: 'Mes données', children: [
            SettingsTile(
              icon: Icons.cloud_upload_outlined,
              title: 'Sauvegarder',
              subtitle: 'Un fichier protégé par mot de passe',
              onTap: () => context.push('/settings/backup'),
            ),
            SettingsTile(
              icon: Icons.restore,
              title: 'Restaurer une sauvegarde',
              onTap: () => context.push('/settings/restore'),
            ),
            SettingsTile(
              icon: Icons.ios_share,
              title: 'Exporter mes opérations',
              subtitle: 'PDF à partager ou fichier Excel',
              onTap: () => _chooseExport(context),
            ),
            SettingsTile(
              icon: Icons.history,
              title: 'Récupérer mes anciens SMS',
              subtitle: isAgence ? null : 'Gratuit',
              onTap: () => context.push('/historique/import'),
            ),
          ]),

          SettingsSection(title: 'Apparence', children: [
            SettingsTile.toggle(
              icon: Icons.dark_mode_outlined,
              title: 'Mode sombre',
              value: isDark,
              onChanged: (_) => ref.read(themeModeProvider.notifier).toggleTheme(),
            ),
          ]),

          SettingsSection(title: 'Aide', children: [
            SettingsTile(
              icon: Icons.sms_failed_outlined,
              title: 'Un SMS n\'a pas été détecté ?',
              subtitle: 'Vérifier et corriger en quelques gestes',
              onTap: () => context.push('/settings/aide-detection'),
            ),
          ]),

          SettingsSection(title: 'Pour aller plus loin', children: [
            SettingsTile(
              icon: Icons.tune,
              title: 'Paramètres avancés',
              subtitle: isAgence
                  ? 'Opérateurs, USSD et commissions, modèles de SMS, diagnostic'
                  : 'Opérateurs, modèles de SMS, motifs et règles, diagnostic',
              onTap: () => context.push('/settings/avances'),
            ),
          ]),
        ],
      ),
    );
  }

  /// Un seul point d'entrée « Exporter » : le format se choisit ensuite.
  void _chooseExport(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Relevé PDF'),
              subtitle: const Text('Propre à imprimer ou à partager'),
              onTap: () {
                Navigator.pop(sheet);
                context.push('/export/pdf');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: const Text('Fichier Excel (CSV)'),
              subtitle: const Text('Pour faire vos propres calculs'),
              onTap: () {
                Navigator.pop(sheet);
                context.push('/export/csv');
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
