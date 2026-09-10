import 'dart:convert';
import 'package:http/http.dart' as http;
import '../licence/licence_service.dart';
import '../licence/licence_storage.dart';

const _syncBaseUrl = 'https://api.money-tracking.site/api/sync';
// const _syncBaseUrl = 'http://localhost:8000/api/sync';
const _licenceBaseUrl = 'https://api.money-tracking.site/api/licence';
// const _licenceBaseUrl = 'http://localhost:8000/api/licence';

/// Rattachement d'un agent à un "patron" multi-agence (D-affiliation) —
/// saisie du numéro du patron (mécanisme confirmé), en attente
/// d'approbation avant de pouvoir opérer une agence. Concerne uniquement
/// les comptes Agence.
class AffiliationService {
  static Future<AffiliationResultat> demander({
    required String demandeurTelephone,
    required String patronTelephone,
  }) async {
    final deviceId = await LicenceService.getDeviceId();
    try {
      final response = await http
          .post(
            Uri.parse('$_syncBaseUrl/demander-affiliation/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'demandeur_telephone': demandeurTelephone,
              'demandeur_device_id': deviceId,
              'patron_telephone': patronTelephone,
            }),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(response.body);
      if (response.statusCode == 201 || response.statusCode == 200) {
        return AffiliationResultat.succes(
          data['message'] as String? ?? 'Demande envoyée',
        );
      }
      return AffiliationResultat.erreur(
        data['erreur'] as String? ?? 'Erreur inconnue',
      );
    } catch (_) {
      return AffiliationResultat.erreur(
        'Impossible de se connecter au serveur',
      );
    }
  }

  /// Poll jusqu'à approbation/rejet (même principe que
  /// LicenceService.attendreValidation) — 24h max, toutes les 10s.
  static Stream<AffiliationStatutPoll> attendreApprobation() async* {
    final deviceId = await LicenceService.getDeviceId();
    for (int i = 0; i < 8640; i++) {
      // 8640 * 10s = 24h max
      try {
        final response = await http
            .get(
              Uri.parse(
                '$_syncBaseUrl/affiliation-statut/?device_id=$deviceId',
              ),
            )
            .timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final statut = data['statut'] as String?;
          if (statut == 'approuve') {
            yield AffiliationStatutPoll.approuve(
              agenceId: data['agence_id'] as int,
              agenceNom: data['agence_nom'] as String,
              licenceCode: data['licence_code'] as String?,
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
  /// (réutilise le flux licence normal — voir RecupererLicenceView côté
  /// backend, agence-scopé, pas téléphone-scopé, pour ce cas précis).
  static Future<bool> recupererLicencePourAgence({
    required String telephone,
    required int agenceId,
  }) async {
    final deviceId = await LicenceService.getDeviceId();
    try {
      final response = await http
          .post(
            Uri.parse('$_licenceBaseUrl/recuperer/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'telephone': telephone,
              'device_id': deviceId,
              'agence_id': agenceId,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return false;
      final data = jsonDecode(response.body);
      if (data['statut'] != 'active' && data['statut'] != 'essai') return false;
      await LicenceStorage.sauvegarder(data);
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
