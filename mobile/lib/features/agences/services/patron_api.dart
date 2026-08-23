import 'dart:convert';
import 'package:http/http.dart' as http;

const _syncBaseUrl = 'https://api-money-tracking.rf-appdev.online/api/sync';
// const _syncBaseUrl = 'http://localhost:8000/api/sync';
const _licenceBaseUrl = 'https://api-money-tracking.rf-appdev.online/api/licence';
// const _licenceBaseUrl = 'http://localhost:8000/api/licence';

/// Vue "patron" multi-agence (D-affiliation) — visibilité en lecture seule
/// confirmée, jamais d'écriture distante sur une agence affiliée.
class PatronApi {
  static Future<List<Map<String, dynamic>>> demandesEnAttente(String telephone) async {
    final res = await http
        .get(Uri.parse('$_syncBaseUrl/demandes-en-attente/?telephone=$telephone'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['demandes'] as List);
  }

  static Future<List<Map<String, dynamic>>> mesAgencesOwned(String telephone) async {
    final res = await http
        .get(Uri.parse('$_licenceBaseUrl/agences/?telephone=$telephone'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['agences'] as List);
  }

  static Future<List<Map<String, dynamic>>> mesAgencesSync(String telephone) async {
    final res = await http
        .get(Uri.parse('$_syncBaseUrl/mes-agences/?telephone=$telephone'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return [];
    final data = jsonDecode(res.body);
    return List<Map<String, dynamic>>.from(data['agences'] as List);
  }

  static Future<Map<String, dynamic>?> agenceDetail(String telephone, int agenceId) async {
    final res = await http
        .get(Uri.parse('$_syncBaseUrl/agence-detail/$agenceId/?telephone=$telephone'))
        .timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) return null;
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  static Future<String?> approuver({
    required String telephone,
    required int demandeId,
    required int agenceId,
  }) async {
    final res = await http
        .post(
          Uri.parse('$_syncBaseUrl/affiliation/$demandeId/approuver/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'telephone': telephone, 'agence_id': agenceId}),
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
    final res = await http
        .post(
          Uri.parse('$_syncBaseUrl/affiliation/$demandeId/rejeter/'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'telephone': telephone}),
        )
        .timeout(const Duration(seconds: 15));
    final data = jsonDecode(res.body);
    if (res.statusCode == 200) return null;
    return data['erreur'] as String? ?? 'Erreur inconnue';
  }
}
