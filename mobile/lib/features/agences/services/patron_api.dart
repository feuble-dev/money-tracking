import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/config/api_config.dart';
import '../../../core/licence/licence_service.dart';

const _syncBaseUrl = ApiConfig.sync;
const _licenceBaseUrl = ApiConfig.licence;

/// Vue "patron" multi-agence (D-affiliation) — visibilité en lecture seule
/// confirmée, jamais d'écriture distante sur une agence affiliée.
///
/// Chaque appel envoie le `device_id` : le backend n'accepte plus le seul
/// numéro du patron (un numéro n'est pas un secret — voir
/// backend/licences/auth.py).
class PatronApi {
  static String _q(String v) => Uri.encodeQueryComponent(v);

  static Future<List<Map<String, dynamic>>> demandesEnAttente(
    String telephone,
  ) async {
    final deviceId = await LicenceService.getDeviceId();
    final res = await http
        .get(
          Uri.parse('$_syncBaseUrl/demandes-en-attente/'
              '?telephone=${_q(telephone)}&device_id=${_q(deviceId)}'),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['demandes'] as List);
  }

  static Future<List<Map<String, dynamic>>> mesAgencesOwned(
    String telephone,
  ) async {
    final deviceId = await LicenceService.getDeviceId();
    final res = await http
        .get(Uri.parse('$_licenceBaseUrl/agences/'
            '?telephone=${_q(telephone)}&device_id=${_q(deviceId)}'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['agences'] as List);
  }

  static Future<List<Map<String, dynamic>>> mesAgencesSync(
    String telephone,
  ) async {
    final deviceId = await LicenceService.getDeviceId();
    final res = await http
        .get(Uri.parse('$_syncBaseUrl/mes-agences/'
            '?telephone=${_q(telephone)}&device_id=${_q(deviceId)}'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['agences'] as List);
  }

  static Future<Map<String, dynamic>?> agenceDetail(
    String telephone,
    int agenceId,
  ) async {
    final deviceId = await LicenceService.getDeviceId();
    final res = await http
        .get(
          Uri.parse(
            '$_syncBaseUrl/agence-detail/$agenceId/'
            '?telephone=${_q(telephone)}&device_id=${_q(deviceId)}',
          ),
        )
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<String?> approuver({
    required String telephone,
    required int demandeId,
    required int agenceId,
  }) async {
    final deviceId = await LicenceService.getDeviceId();
    final res = await http
        .post(
          Uri.parse('$_syncBaseUrl/affiliation/$demandeId/approuver/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'telephone': telephone,
            'device_id': deviceId,
            'agence_id': agenceId,
          }),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return null;
    return data['erreur'] as String? ?? 'Erreur inconnue';
  }

  static Future<String?> rejeter({
    required String telephone,
    required int demandeId,
  }) async {
    final deviceId = await LicenceService.getDeviceId();
    final res = await http
        .post(
          Uri.parse('$_syncBaseUrl/affiliation/$demandeId/rejeter/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'telephone': telephone, 'device_id': deviceId}),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return null;
    return data['erreur'] as String? ?? 'Erreur inconnue';
  }
}
