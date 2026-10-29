import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import '../network/api_client.dart';
import '../security/device_identity.dart';
import 'licence_storage.dart';
import 'offline_key.dart';

const String _baseUrl = ApiConfig.licence;
const _erreurReseau = 'Impossible de se connecter au serveur';

class LicenceService {
  /// Identifiant de cette installation (voir [DeviceIdentity]).
  static Future<String> getDeviceId() => DeviceIdentity.id();

  // ── Vérification au démarrage ─────────────────────────────
  static Future<LicenceStatut> verifierAuDemarrage() async {
    // 1. Vérifier d'abord en local (fonctionne offline)
    final statut = await LicenceStorage.verifierLocalement();

    if (statut.permetEcriture) {
      // Licence locale valide → sync en arrière-plan
      _syncEnArrierePlan();
      return statut;
    }

    // 2. Si pas de licence locale → tenter récupération en ligne
    final connecte = await _estConnecte();
    if (connecte) {
      await ensureDeviceRegistered();
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
      await ensureDeviceRegistered();
      await OfflineKey.refreshPublicKey();
      final telephone = await LicenceStorage.getTelephone();
      if (telephone == null) return;
      await recupererLicence(telephone);
    } catch (_) {}
  }

  /// Installation antérieure au jeton d'appareil : réclame son jeton une
  /// seule fois (backend `appareil/enregistrer/`). Sans effet si l'appareil
  /// en a déjà un ou n'a jamais été inscrit.
  static Future<void> ensureDeviceRegistered() async {
    if (await DeviceIdentity.hasToken()) return;
    if (await LicenceStorage.getTelephone() == null) return;
    try {
      final res = await ApiClient.post('$_baseUrl/appareil/enregistrer/',
          {'device_id': await getDeviceId()});
      if (!res.ok) {
        debugPrint('[Licence] Enregistrement appareil : ${res.statusCode} ${res.error()}');
      }
    } catch (_) {}
  }

  // ── MODE 1 : Essai gratuit ────────────────────────────────
  static Future<ResultatActivation> demarrerEssai(String telephone) async {
    try {
      final res = await ApiClient.post('$_baseUrl/essai/', {
        'telephone': telephone,
        'device_id': await getDeviceId(),
      });
      if (res.statusCode == 201) {
        await LicenceStorage.sauvegarder(res.data);
        await LicenceStorage.saveTelephone(telephone);
        return ResultatActivation.succes(res.data['message'] as String? ??
            'Essai gratuit activé');
      }
      return ResultatActivation.erreur(res.error());
    } catch (_) {
      return ResultatActivation.erreur(_erreurReseau);
    }
  }

  // ── MODE 2 : Récupération en ligne (polling) ──────────────
  static Future<bool> recupererLicence(String telephone) async {
    try {
      final res = await ApiClient.post('$_baseUrl/recuperer/', {
        'telephone': telephone,
        'device_id': await getDeviceId(),
      }, timeout: const Duration(seconds: 10));
      if (res.ok &&
          (res.data['statut'] == 'active' || res.data['statut'] == 'essai')) {
        await LicenceStorage.sauvegarder(res.data);
        await LicenceStorage.saveTelephone(telephone);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ── MODE 2 : Attente validation (polling 30 sec) ──────────
  static Stream<StatutDemande> attendreValidation(String telephone) async* {
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

  // ── MODE 3 : Activation avec clé ──────────────────────────
  /// En ligne, le serveur vérifie la clé (ancien format `MT-…` comme
  /// nouveau `MT2-…`). Hors ligne, seule une clé signée `MT2-…` est
  /// acceptée, vérifiée avec la clé publique du serveur : l'ancien format
  /// n'était pas signé, n'importe quelle clé bien formée passait.
  static Future<ResultatActivation> activerAvecCle(
    String cle,
    String telephone,
  ) async {
    final deviceId = await getDeviceId();
    final saisie = cle.trim();
    final signee = OfflineKey.looksLike(saisie);
    final code = signee ? saisie : saisie.toUpperCase();

    try {
      final res = await ApiClient.post('$_baseUrl/verifier-cle/',
          {'code': code, 'device_id': deviceId},
          timeout: const Duration(seconds: 10));
      if (res.ok) {
        if (res.data['valide'] != true) {
          return ResultatActivation.erreur(
              res.data['message'] as String? ?? 'Clé invalide');
        }
        final jours = (res.data['jours_restants'] as num?)?.toInt() ?? 0;
        await LicenceStorage.sauvegarder({
          'statut': res.data['statut'] ?? 'active',
          'code': code,
          'date_fin': res.data['date_fin'],
          'jours_restants': jours,
          'source': 'cle_manuelle',
        });
        await LicenceStorage.saveTelephone(telephone);
        return ResultatActivation.succes(
            'Licence activée - expire dans $jours jours');
      }
      if (!res.needsDeviceAuth) return ResultatActivation.erreur(res.error());
      // Appareil pas encore authentifié : la vérification locale suffit
      // pour une clé signée.
    } catch (_) {
      // Pas de réseau : vérification locale ci-dessous.
    }

    if (!signee) {
      return ResultatActivation.erreur(
          'Connectez-vous à Internet pour activer cette clé.');
    }
    final licence = await OfflineKey.verify(code, deviceId);
    if (licence == null) {
      return ResultatActivation.erreur('Clé invalide pour cet appareil');
    }
    final jours = licence.dateFin.difference(DateTime.now()).inDays;
    if (jours < 0) return ResultatActivation.erreur('Cette clé a expiré');
    await LicenceStorage.sauvegarder({
      'statut': licence.statut,
      'code': code,
      'agence_id': licence.agenceId,
      'date_fin': licence.dateFin.toIso8601String(),
      'jours_restants': jours,
      'source': 'cle_hors_ligne',
    });
    await LicenceStorage.saveTelephone(telephone);
    return ResultatActivation.succes('Licence activée - expire dans $jours jours');
  }

  // ── Onboarding : compte + 1ère agence + essai (D7/D8/D10) ─
  static Future<ResultatEssaiAgence> demarrerEssaiAvecAgence({
    required String telephone,
    required String accountType,
    required String agenceNom,
    // Mot de passe compte (D13) — obligatoire à la création, permet
    // ensuite une connexion instantanée depuis un autre appareil (login()
    // ci-dessous) sans passer par l'affiliation/approbation.
    required String password,
  }) async {
    try {
      final res = await ApiClient.post('$_baseUrl/essai/', {
        'telephone': telephone,
        'device_id': await getDeviceId(),
        'account_type': accountType,
        'agence_nom': agenceNom,
        'password': password,
      });
      if (res.statusCode == 201) {
        await LicenceStorage.sauvegarder(res.data);
        await LicenceStorage.saveTelephone(telephone);
        return ResultatEssaiAgence.succes(
          agenceBackendId: res.data['agence_id'] as int,
          message: res.data['message'] as String? ?? 'Compte créé',
        );
      }
      return ResultatEssaiAgence.erreur(res.error());
    } catch (_) {
      return ResultatEssaiAgence.erreur(_erreurReseau);
    }
  }

  // ── Demande d'activation ──────────────────────────────────
  static Future<ResultatActivation> demanderActivation({
    required String telephone,
    required int dureeMois,
  }) async {
    try {
      final res = await ApiClient.post('$_baseUrl/demander/', {
        'telephone': telephone,
        'device_id': await getDeviceId(),
        'duree_mois': dureeMois,
      });
      if (res.statusCode == 201) {
        await LicenceStorage.saveTelephone(telephone);
        return ResultatActivation.succes(res.data['message'] as String? ??
            'Demande envoyée');
      }
      return ResultatActivation.erreur(res.error());
    } catch (_) {
      return ResultatActivation.erreur(_erreurReseau);
    }
  }

  // ── Connexion à un compte existant depuis un nouvel appareil (D13) ──
  // Le mot de passe prouve la propriété du compte : aucune approbation
  // manuelle nécessaire (contrairement à AffiliationService.demander). Le
  // serveur émet au passage le jeton de cet appareil.
  static Future<ResultatLogin> login({
    required String telephone,
    required String password,
  }) async {
    try {
      final res = await ApiClient.post('$_baseUrl/login/', {
        'telephone': telephone,
        'password': password,
        'device_id': await getDeviceId(),
      });
      if (res.ok) {
        final agences = ((res.data['agences'] as List?) ?? [])
            .map((a) => AgenceLogin.fromJson(a as Map<String, dynamic>))
            .toList();
        return ResultatLogin.succes(
          accountType: res.data['account_type'] as String? ?? 'agence',
          agences: agences,
        );
      }
      if (res.statusCode == 429) {
        return ResultatLogin.erreur(
            'Trop de tentatives. Réessayez dans une minute.');
      }
      return ResultatLogin.erreur(res.error('Identifiants incorrects'));
    } catch (_) {
      return ResultatLogin.erreur(_erreurReseau);
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

class ResultatEssaiAgence {
  final bool reussi;
  final String message;
  final int? agenceBackendId;
  ResultatEssaiAgence.succes({
    required this.agenceBackendId,
    required this.message,
  }) : reussi = true;
  ResultatEssaiAgence.erreur(this.message)
    : reussi = false,
      agenceBackendId = null;
}

/// Agence retournée par LoginView — uniquement celles réellement utilisables
/// (statut 'active'/'essai') doivent être proposées au choix de l'utilisateur.
class AgenceLogin {
  final int id;
  final String nom;
  final String statut;
  AgenceLogin({required this.id, required this.nom, required this.statut});
  factory AgenceLogin.fromJson(Map<String, dynamic> json) => AgenceLogin(
    id: json['id'] as int,
    nom: json['nom'] as String,
    statut: json['statut'] as String? ?? 'expiree',
  );
}

class ResultatLogin {
  final bool reussi;
  final String message;
  final String? accountType;
  final List<AgenceLogin> agences;
  ResultatLogin.succes({required this.accountType, required this.agences})
    : reussi = true,
      message = '';
  ResultatLogin.erreur(this.message)
    : reussi = false,
      accountType = null,
      agences = const [];
}
