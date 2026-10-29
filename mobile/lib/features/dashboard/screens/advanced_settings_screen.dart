import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/onboarding/onboarding_state.dart';
import '../../../core/security/device_identity.dart';
import '../../../shared/widgets/operator_avatar.dart';
import '../../../shared/widgets/settings_tiles.dart';
import '../../operators/providers/operator_provider.dart';
import '../diagnostic_actions.dart';

/// Identifiant d'installation réel (celui que le serveur connaît, D21) —
/// utile au support. L'ancien écran affichait `Build.ID`, faux et partagé
/// par tous les téléphones d'un même firmware.
final _deviceIdProvider = FutureProvider<String>((ref) => DeviceIdentity.id());

/// Réglages pour les utilisateurs avancés : opérateurs (USSD, commissions,
/// modèles de SMS), organisation, outils de diagnostic. Rien ici n'est
/// nécessaire au quotidien — tout fonctionne avec les valeurs par défaut.
class AdvancedSettingsScreen extends ConsumerWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAgence = ref.watch(accountTypeProvider).valueOrNull == 'agence';
    final operators = ref.watch(operatorsProvider).valueOrNull ?? const [];
    final deviceId = ref.watch(_deviceIdProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres avancés')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          SettingsSection(title: 'Opérateurs', children: [
            for (final op in operators.where((o) => o.isActive))
              ListTile(
                leading: OperatorAvatar(name: op.name, logoPath: op.logoPath, radius: 18),
                title: Text(op.name),
                subtitle: Text(isAgence
                    ? 'USSD, commissions, modèles de SMS'
                    : 'Modèles de SMS'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/operators/edit/${op.id}'),
              ),
            SettingsTile(
              icon: Icons.add,
              title: 'Ajouter un opérateur',
              onTap: () => context.push('/operators/add'),
            ),
          ]),

          SettingsSection(title: 'Organisation', children: [
            if (!isAgence)
              SettingsTile(
                icon: Icons.label_outline,
                title: 'Motifs et règles',
                subtitle: 'Vos motifs de dépense, rangements automatiques',
                onTap: () => context.push('/categories/manage'),
              ),
            SettingsTile(
              icon: Icons.account_balance_outlined,
              title: isAgence ? 'Caisse et float' : 'Soldes Mobile Money',
              subtitle: isAgence
                  ? 'Soldes, rechargements, seuil d\'alerte'
                  : 'Corriger un solde affiché',
              onTap: () => context.push('/settings/caisse'),
            ),
          ]),

          SettingsSection(title: 'Détection des SMS', children: [
            SettingsTile(
              icon: Icons.sync,
              title: 'Mettre à jour les modèles de SMS',
              subtitle: 'Fait aussi automatiquement à chaque ouverture',
              onTap: () => resynchroniserCatalogue(context, ref),
            ),
            SettingsTile(
              icon: Icons.content_paste_search,
              title: 'Tester un SMS',
              onTap: () => context.push('/settings/sms-test'),
            ),
            SettingsTile(
              icon: Icons.list_alt,
              title: 'Journal des SMS reçus',
              subtitle: 'Chaque SMS et ce qu\'il est devenu',
              onTap: () => context.push('/settings/sms-journal'),
            ),
            SettingsTile(
              icon: Icons.battery_saver_outlined,
              title: 'Fonctionnement en arrière-plan',
              onTap: () => demanderExemptionBatterie(context),
            ),
          ]),

          SettingsSection(title: 'Cet appareil', children: [
            SettingsTile(
              icon: Icons.smartphone,
              title: 'Identifiant pour le support',
              subtitle: deviceId ?? '…',
              trailing: const Icon(Icons.copy, size: 18),
              onTap: deviceId == null
                  ? null
                  : () {
                      Clipboard.setData(ClipboardData(text: deviceId));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Identifiant copié')),
                      );
                    },
            ),
          ]),

          Center(
            child: Text(
              'MoneyTracking 1.0.0 · FEUBLE-TechBuilder',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
