import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/onboarding/catalog_sync_service.dart';
import '../../core/onboarding/onboarding_state.dart';

/// Actions de dépannage de la détection SMS, partagées par l'aide
/// « Un SMS n'a pas été détecté ? » et les paramètres avancés.

/// Redemande le catalogue au serveur pour les opérateurs déjà importés —
/// répare immédiatement une détection cassée par un pattern SMS mal tagué
/// côté admin (CatalogSyncService.resyncOperators), sans attendre le
/// prochain démarrage de l'app (qui le fait aussi automatiquement).
Future<void> resynchroniserCatalogue(BuildContext context, WidgetRef ref) async {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Mise à jour des modèles de SMS…')),
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
              ? '$changed modèle(s) de SMS mis à jour'
              : 'Les modèles de SMS sont déjà à jour',
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Pas de connexion - réessayez plus tard')),
    );
  }
}

/// Demande l'exemption d'optimisation batterie — nécessaire sur beaucoup
/// d'appareils (Xiaomi, Tecno, Infinix, Samsung...) pour que la détection
/// SMS continue de fonctionner quand l'app est fermée. Toujours précédé
/// d'une explication : jamais demandé silencieusement.
Future<void> demanderExemptionBatterie(BuildContext context) async {
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
