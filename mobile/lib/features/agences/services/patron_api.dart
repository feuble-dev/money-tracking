import '../../../core/config/api_config.dart';
import '../../../core/licence/licence_service.dart';
import '../../../core/network/api_client.dart';

const _syncBaseUrl = ApiConfig.sync;
const _licenceBaseUrl = ApiConfig.licence;

/// Vue "patron" multi-agence (D-affiliation) — visibilité en lecture seule
/// confirmée, jamais d'écriture distante sur une agence affiliée.
///
/// Le backend exige le jeton de l'appareil ET que cet appareil soit l'un
/// de ceux du propriétaire (voir backend/licences/auth.py) : le numéro du
/// patron seul ne donne accès à rien.
class PatronApi {
  static Future<Map<String, String>> _who(String telephone) async => {
        'telephone': telephone,
        'device_id': await LicenceService.getDeviceId(),
      };

  static List<Map<String, dynamic>> _list(ApiResponse res, String key) =>
      res.ok ? List<Map<String, dynamic>>.from(res.data[key] as List? ?? []) : [];

  static Future<List<Map<String, dynamic>>> demandesEnAttente(
          String telephone) async =>
      _list(
          await ApiClient.get('$_syncBaseUrl/demandes-en-attente/',
              query: await _who(telephone)),
          'demandes');

  static Future<List<Map<String, dynamic>>> mesAgencesOwned(
          String telephone) async =>
      _list(
          await ApiClient.get('$_licenceBaseUrl/agences/',
              query: await _who(telephone)),
          'agences');

  static Future<List<Map<String, dynamic>>> mesAgencesSync(
          String telephone) async =>
      _list(
          await ApiClient.get('$_syncBaseUrl/mes-agences/',
              query: await _who(telephone)),
          'agences');

  static Future<Map<String, dynamic>?> agenceDetail(
    String telephone,
    int agenceId,
  ) async {
    final res = await ApiClient.get('$_syncBaseUrl/agence-detail/$agenceId/',
        query: await _who(telephone));
    return res.ok ? res.data : null;
  }

  /// `null` si OK, sinon le message d'erreur.
  static Future<String?> approuver({
    required String telephone,
    required int demandeId,
    required int agenceId,
  }) async {
    final res = await ApiClient.post(
        '$_syncBaseUrl/affiliation/$demandeId/approuver/',
        {...await _who(telephone), 'agence_id': agenceId});
    return res.ok ? null : res.error();
  }

  static Future<String?> rejeter({
    required String telephone,
    required int demandeId,
  }) async {
    final res = await ApiClient.post(
        '$_syncBaseUrl/affiliation/$demandeId/rejeter/', await _who(telephone));
    return res.ok ? null : res.error();
  }
}
