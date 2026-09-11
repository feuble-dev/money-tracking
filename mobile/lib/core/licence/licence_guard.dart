import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../historique/historique_storage.dart';
import '../onboarding/onboarding_state.dart';
import 'licence_storage.dart';

enum ActionType {
  // Toujours autorisé — lecture seule
  consulterDashboard,
  voirHistorique,
  voirClients,
  exporterPDF,
  exporterExcel,
  exporterCSV,
  recevoirSMS,

  // Nécessite achat historique
  importerHistoriqueSMS,

  // Nécessite licence active
  confirmerTransaction,
  creerTransactionManuelle,
  ajouterClient,
  modifierClient,
  configurerOperateur,
  modifierTemplateSMS,
  lancerUSSD,
  rechargerCaisse,
}

class LicenceGuard {
  // Actions TOUJOURS autorisées
  static const _actionsLibres = {
    ActionType.consulterDashboard,
    ActionType.voirHistorique,
    ActionType.voirClients,
    ActionType.exporterPDF,
    ActionType.exporterExcel,
    ActionType.exporterCSV,
    ActionType.recevoirSMS,
  };

  /// Vérifie si une action est autorisée.
  /// Si non → affiche le dialog de licence.
  static Future<bool> verifier(
    BuildContext context,
    ActionType action,
  ) async {
    // Un compte Particulier n'est jamais un flux payant : ni licence ni
    // achat d'historique SMS — seul un compte Agence est facturé (D8/D-
    // particulier-gratuit). On ne restreint donc rien pour ce profil, quel
    // que soit l'état de son essai/licence sous le capot.
    final accountType = await OnboardingStatusService().getAccountType();
    if (accountType == 'particulier') return true;

    // Action libre → toujours OK
    if (_actionsLibres.contains(action)) return true;

    // Cas spécial: import historique
    if (action == ActionType.importerHistoriqueSMS) {
      final actif = await HistoriqueStorage.estActive();
      if (!actif && context.mounted) {
        await _afficherDialogHistorique(context);
        return false;
      }
      return actif;
    }

    // Vérifier la licence
    final statut = await LicenceStorage.verifierLocalement();

    final autorise = statut == LicenceStatut.active ||
        statut == LicenceStatut.essaiActif ||
        statut == LicenceStatut.expireBientot;

    if (!autorise && context.mounted) {
      await _afficherDialogLicence(context, statut);
      return false;
    }
    return autorise;
  }

  /// Dialog affiché quand une action protégée est tentée
  static Future<void> _afficherDialogLicence(
    BuildContext context,
    LicenceStatut statut,
  ) async {
    final estExpiree = statut == LicenceStatut.expiree;

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          estExpiree ? 'Licence expirée' : 'Licence requise',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              estExpiree
                  ? 'Votre licence a expiré. Renouvelez pour '
                      'continuer à créer des transactions.'
                  : 'Cette action nécessite une licence active.',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Toujours disponible gratuitement :',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '- Consultation de l\'historique',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    '- Export PDF / Excel',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    '- Détection SMS automatique',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    '- Voir le dashboard',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/activation');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
            ),
            child: Text(
              estExpiree ? 'Renouveler' : 'Activer ma licence',
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _afficherDialogHistorique(
    BuildContext context,
  ) async {
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Import Historique SMS'),
        content: const Text(
          'Gratuit jusqu\'à 1 an en arrière. Au-delà, 200 FCFA par année '
          'supplémentaire - le prix exact dépend de la période choisie.\n\n'
          'Illimité sur cet appareil une fois activé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Plus tard'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/historique/import');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
            ),
            child: const Text('Choisir une période'),
          ),
        ],
      ),
    );
  }
}
