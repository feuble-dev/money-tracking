import '../config/api_config.dart';
import '../licence/licence_service.dart';
import '../licence/licence_storage.dart';
import '../network/api_client.dart';

const _syncBaseUrl = ApiConfig.sync;
const _licenceBaseUrl = ApiConfig.licence;

/// Rattachement d'un agent à un "patron" multi-agence (D-affiliation) —
/// saisie du numéro du patron (mécanisme confirmé), en attente
/// d'approbation avant de pouvoir opérer une agence. La première demande
/// d'un nouvel appareil lui fait aussi émettre son jeton d'appareil
/// (mémorisé automatiquement par [ApiClient]).
class AffiliationService {
  static Future<AffiliationResultat> demander({
    required String demandeurTelephone,
    required String patronTelephone,
  }) async {
    try {
      final res = await ApiClient.post('$_syncBaseUrl/demander-affiliation/', {
        'demandeur_telephone': demandeurTelephone,
        'demandeur_device_id': await LicenceService.getDeviceId(),
        'patron_telephone': patronTelephone,
      });
      if (res.ok) {
        return AffiliationResultat.succes(
            res.data['message'] as String? ?? 'Demande envoyée');
      }
      return AffiliationResultat.erreur(res.error());
    } catch (_) {
      return AffiliationResultat.erreur('Impossible de se connecter au serveur');
    }
  }

  /// Poll jusqu'à approbation/rejet — 24h max, toutes les 10s.
  static Stream<AffiliationStatutPoll> attendreApprobation() async* {
    final deviceId = await LicenceService.getDeviceId();
    for (int i = 0; i < 8640; i++) {
      // 8640 * 10s = 24h max
      try {
        final res = await ApiClient.get('$_syncBaseUrl/affiliation-statut/',
            query: {'device_id': deviceId},
            timeout: const Duration(seconds: 10));
        if (res.ok) {
          final statut = res.data['statut'] as String?;
          if (statut == 'approuve') {
            yield AffiliationStatutPoll.approuve(
              agenceId: res.data['agence_id'] as int,
              agenceNom: res.data['agence_nom'] as String,
              licenceCode: res.data['licence_code'] as String?,
            );
            return;
          }
          if (statut == 'rejete') {
            yield AffiliationStatutPoll.rejete();
            return;
          }
        }
      } catch (_) {}
      yield AffiliationStatutPoll.enAttente();
      await Future.delayed(const Duration(seconds: 10));
    }
    yield AffiliationStatutPoll.timeout();
  }

  /// Récupère la licence émise pour ce device sur l'agence assignée
  /// (RecupererLicenceView côté backend, agence-scopé).
  static Future<bool> recupererLicencePourAgence({
    required String telephone,
    required int agenceId,
  }) async {
    try {
      final res = await ApiClient.post('$_licenceBaseUrl/recuperer/', {
        'telephone': telephone,
        'device_id': await LicenceService.getDeviceId(),
        'agence_id': agenceId,
      });
      if (!res.ok) return false;
      final statut = res.data['statut'];
      if (statut != 'active' && statut != 'essai') return false;
      await LicenceStorage.sauvegarder(res.data);
      await LicenceStorage.saveTelephone(telephone);
      return true;
    } catch (_) {
      return false;
    }
  }
}

class AffiliationResultat {
  final bool reussi;
  final String message;
  AffiliationResultat.succes(this.message) : reussi = true;
  AffiliationResultat.erreur(this.message) : reussi = false;
}

class AffiliationStatutPoll {
  final String statut; // 'en_attente' | 'approuve' | 'rejete' | 'timeout'
  final int? agenceId;
  final String? agenceNom;
  final String? licenceCode;

  AffiliationStatutPoll._(
    this.statut, {
    this.agenceId,
    this.agenceNom,
    this.licenceCode,
  });

  factory AffiliationStatutPoll.enAttente() =>
      AffiliationStatutPoll._('en_attente');
  factory AffiliationStatutPoll.rejete() => AffiliationStatutPoll._('rejete');
  factory AffiliationStatutPoll.timeout() => AffiliationStatutPoll._('timeout');
  factory AffiliationStatutPoll.approuve({
    required int agenceId,
    required String agenceNom,
    String? licenceCode,
  }) => AffiliationStatutPoll._(
    'approuve',
    agenceId: agenceId,
    agenceNom: agenceNom,
    licenceCode: licenceCode,
  );
}
