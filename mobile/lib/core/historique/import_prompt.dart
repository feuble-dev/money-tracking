import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../onboarding/onboarding_state.dart';

/// Proposition de récupérer les anciens SMS : faite juste après
/// l'installation, puis à chaque ouverture de l'app tant que l'import n'a
/// pas eu lieu (ou que l'utilisateur n'a pas dit « ne plus demander »).
class ImportPrompt {
  ImportPrompt._();

  static const _kDone = 'history_import_done';
  static const _kNever = 'history_import_never_ask';

  /// À appeler quand un import s'est terminé : on ne redemande plus.
  static Future<void> markDone() async =>
      (await SharedPreferences.getInstance()).setBool(_kDone, true);

  static Future<void> neverAskAgain() async =>
      (await SharedPreferences.getInstance()).setBool(_kNever, true);

  /// Faut-il poser la question maintenant ? [hasSmsPermission] est passé
  /// par l'appelant (canal natif) pour garder cette règle testable.
  static Future<bool> shouldAsk({required bool hasSmsPermission}) async {
    if (!hasSmsPermission) return false; // rien à lire : on redemandera
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kDone) == true || prefs.getBool(_kNever) == true) {
      return false;
    }
    if (!await OnboardingStatusService().isComplete()) return false;
    // Installation existante qui a déjà importé avant cette fonctionnalité.
    final db = await DatabaseHelper.instance.database;
    final imported = await db.rawQuery(
        "SELECT 1 FROM transactions WHERE source = 'sms_import' LIMIT 1");
    if (imported.isNotEmpty) {
      await markDone();
      return false;
    }
    return true;
  }

  /// Affiche la proposition. « Importer » ouvre l'écran d'import.
  static Future<void> show(BuildContext context, {required bool isParticulier}) {
    return showDialog<void>(
      context: context,
      builder: (d) => AlertDialog(
        icon: const Icon(Icons.history, size: 32),
        title: const Text('Récupérer vos anciens SMS ?'),
        content: Text(
          'Vos SMS Mobile Money déjà reçus peuvent devenir des opérations : '
          'vous retrouvez tout votre historique dès aujourd\'hui.\n\n'
          '${isParticulier ? 'C\'est gratuit.' : 'Gratuit jusqu\'à un an en arrière.'} '
          'Tout se passe sur votre téléphone.',
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: () async {
              await neverAskAgain();
              if (d.mounted) Navigator.of(d).pop();
            },
            child: const Text('Ne plus demander'),
          ),
          Row(mainAxisSize: MainAxisSize.min, children: [
            TextButton(
              onPressed: () => Navigator.of(d).pop(),
              child: const Text('Plus tard'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              onPressed: () {
                Navigator.of(d).pop();
                GoRouter.of(context).push('/historique/import');
              },
              child: const Text('Importer'),
            ),
          ]),
        ],
      ),
    );
  }
}
