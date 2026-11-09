import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../diagnostic_actions.dart';

/// « Un SMS n'a pas été détecté ? » — dépannage guidé, étape par étape, au
/// lieu d'une liste d'outils techniques à deviner.
class DetectionHelpScreen extends ConsumerWidget {
  const DetectionHelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = [
      _Step(
        icon: Icons.content_paste_search,
        title: 'Testez le SMS',
        text: 'Collez le message reçu : vous verrez tout de suite s\'il est '
            'reconnu, et comment.',
        action: 'Tester un SMS',
        onTap: () => context.push('/settings/sms-test'),
      ),
      _Step(
        icon: Icons.battery_saver_outlined,
        title: 'Laissez l\'app travailler fermée',
        text: 'Certains téléphones (Tecno, Infinix, Xiaomi, Samsung…) '
            'arrêtent l\'app pour économiser la batterie. Un réglage suffit.',
        action: 'Autoriser',
        onTap: () => demanderExemptionBatterie(context),
      ),
      _Step(
        icon: Icons.sync,
        title: 'Mettez à jour les modèles de SMS',
        text: 'Si votre opérateur a changé la formulation de ses messages, '
            'nous avons peut-être déjà la correction.',
        action: 'Mettre à jour',
        onTap: () => resynchroniserCatalogue(context, ref),
      ),
      _Step(
        icon: Icons.edit_note,
        title: 'Toujours pas ?',
        text: 'Apprenez-lui ce message vous-même : choisissez l\'opérateur '
            'puis « Modèles de SMS ».',
        action: 'Paramètres avancés',
        onTap: () => context.push('/settings/avances'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('SMS non détecté')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text(
            'Suivez ces étapes dans l\'ordre : la plupart des cas se règlent '
            'dès la première ou la deuxième.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++) _StepCard(index: i + 1, step: steps[i]),
          TextButton.icon(
            onPressed: () => context.push('/settings/sms-journal'),
            icon: const Icon(Icons.list_alt),
            label: const Text('Voir tous les SMS reçus'),
          ),
        ],
      ),
    );
  }
}

class _Step {
  final IconData icon;
  final String title;
  final String text;
  final String action;
  final VoidCallback onTap;
  const _Step({
    required this.icon,
    required this.title,
    required this.text,
    required this.action,
    required this.onTap,
  });
}

class _StepCard extends StatelessWidget {
  final int index;
  final _Step step;
  const _StepCard({required this.index, required this.step});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: primary.withAlpha(24),
              child: Text('$index',
                  style: TextStyle(color: primary, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(step.text, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: step.onTap,
                    icon: Icon(step.icon, size: 18),
                    label: Text(step.action),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
