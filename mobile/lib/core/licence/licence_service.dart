import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'licence_storage.dart';
import 'licence_validator.dart';

// Changer par l'URL réelle du backend en production
// const String _baseUrl = 'https://moneytracking.rf.gd/api/licence';
const String _baseUrl = 'https://api-money-tracking.rf-appdev.online/api/licence';

class LicenceService {
  // ── Device ID unique Android ──────────────────────────────
  static Future<String> getDeviceId() async {
    final info = DeviceInfoPlugin();
    final android = await info.androidInfo;
    return android.id;
  }

  // ── Vérification au démarrage ─────────────────────────────
  static Future<LicenceStatut> verifierAuDemarrage() async {
    // 1. Vérifier d'abord en local (fonctionne offline)
    final statut = await LicenceStorage.verifierLocalement();

    if (statut == LicenceStatut.active ||
        statut == LicenceStatut.expireBientot ||
        statut == LicenceStatut.essaiActif) {
      // Licence locale valide → sync en arrière-plan
      _syncEnArrierePlan();
      return statut;
    }

    // 2. Si pas de licence locale → tenter récupération en ligne
    final connecte = await _estConnecte();
    if (connecte) {
      final telephone = await LicenceStorage.getTelephone();
      if (telephone != null) {
        final recuperee = await recupererLicence(telephone);
        if (recuperee) return LicenceStatut.active;
      }
    }

    return statut;
  }

  // ── Sync silencieuse en arrière-plan ─────────────────────
  static Future<void> _syncEnArrierePlan() async {
    try {
      final connecte = await _estConnecte();
      if (!connecte) return;
      final telephone = await LicenceStorage.getTelephone();
      if (telephone == null) return;
      await recupererLicence(telephone);
    } catch (_) {}
  }

  // ── MODE 1 : Essai gratuit ────────────────────────────────
  static Future<ResultatActivation> demarrerEssai(
    String telephone,
  ) async {
    final deviceId = await getDeviceId();
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/essai/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'telephone': telephone,
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);

      if (response.statusCode == 201) {
        await LicenceStorage.sauvegarder(data);
        await LicenceStorage.saveTelephone(telephone);
        return ResultatActivation.succes(
          'Essai gratuit activé pour 30 jours !',
        );
      }
      return ResultatActivation.erreur(
        data['erreur'] ?? 'Erreur inconnue',
      );
    } catch (e) {
      return ResultatActivation.erreur(
        'Impossible de se connecter au serveur',
      );
    }
  }

  // ── MODE 2 : Récupération en ligne (polling) ──────────────
  static Future<bool> recupererLicence(String telephone) async {
    final deviceId = await getDeviceId();
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/recuperer/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'telephone': telephone,
              'device_id': deviceId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['statut'] == 'active' || data['statut'] == 'essai') {
          await LicenceStorage.sauvegarder(data);
          await LicenceStorage.saveTelephone(telephone);
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  // ── MODE 2 : Attente validation (polling 30 sec) ──────────
  static Stream<StatutDemande> attendreValidation(
    String telephone,
  ) async* {
    yield StatutDemande.enAttente;
    for (int i = 0; i < 2880; i++) {
      // 2880 * 30s = 24h max
      await Future.delayed(const Duration(seconds: 30));
      final recuperee = await recupererLicence(telephone);
      if (recuperee) {
        yield StatutDemande.validee;
        return;
      }
      yield StatutDemande.enAttente;
    }
    yield StatutDemande.timeout;
  }

  // ── MODE 3 : Activation avec clé manuelle (offline) ───────
  static Future<ResultatActivation> activerAvecCle(
    String cle,
    String telephone,
  ) async {
    final deviceId = await getDeviceId();
    final resultat = LicenceValidator.valider(
      cle: cle.trim().toUpperCase(),
      deviceId: deviceId,
    );

    if (resultat.valide) {
      await LicenceStorage.sauvegarder({
        'statut': 'active',
        'code': cle.trim().toUpperCase(),
        'date_fin': resultat.dateFin!.toIso8601String(),
        'jours_restants': resultat.joursRestants,
        'source': 'cle_manuelle',
      });
      await LicenceStorage.saveTelephone(telephone);
      return ResultatActivation.succes(
        'Licence activée — expire dans '
        '${resultat.joursRestants} jours',
      );
    }
    return ResultatActivation.erreur(resultat.message);
  }

  // ── Demande d'activation ──────────────────────────────────
  static Future<ResultatActivation> demanderActivation({
    required String telephone,
    required int dureeMois,
  }) async {
    final deviceId = await getDeviceId();
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/demander/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'telephone': telephone,
              'device_id': deviceId,
              'duree_mois': dureeMois,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(response.body);
      if (response.statusCode == 201) {
        await LicenceStorage.saveTelephone(telephone);
        return ResultatActivation.succes(data['message']);
      }
      return ResultatActivation.erreur(data['erreur'] ?? 'Erreur');
    } catch (e) {
      return ResultatActivation.erreur('Impossible de se connecter');
    }
  }

  static Future<bool> _estConnecte() async {
    final results = await Connectivity().checkConnectivity();
    if (results is List) {
      return !(results as List).contains(ConnectivityResult.none);
    }
    return results != ConnectivityResult.none;
  }
}

// ── Modèles ───────────────────────────────────────────────
enum StatutDemande { enAttente, validee, timeout }

class ResultatActivation {
  final bool reussi;
  final String message;
  ResultatActivation.succes(this.message) : reussi = true;
  ResultatActivation.erreur(this.message) : reussi = false;
}
