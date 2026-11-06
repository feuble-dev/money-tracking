import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../security/device_identity.dart';

/// Réponse JSON du backend. [data] vaut `{}` si le corps n'est pas un objet
/// (liste dans [list]).
class ApiResponse {
  final int statusCode;
  final Map<String, dynamic> data;
  final List<dynamic>? list;

  const ApiResponse(this.statusCode, this.data, [this.list]);

  bool get ok => statusCode >= 200 && statusCode < 300;

  /// Le backend renvoie ses erreurs en `{"erreur": "..."}`.
  String error([String fallback = 'Erreur inconnue']) =>
      (data['erreur'] ?? data['message'] ?? fallback).toString();

  /// Jeton d'appareil absent ou invalide (backend : `exige_jeton`).
  bool get needsDeviceAuth =>
      statusCode == 401 && data['code'] == 'jeton_appareil';
}

/// Seul point d'accès HTTP de l'app vers le backend : en-têtes communs
/// (JSON + jeton d'appareil), délai, décodage, et mémorisation automatique
/// de tout `device_token` renvoyé par le serveur.
///
/// Lève une exception réseau (pas de connexion, délai dépassé) : c'est à
/// l'appelant de la traduire en message utilisateur.
class ApiClient {
  ApiClient._();

  @visibleForTesting
  static http.Client httpClient = http.Client();

  static const _defaultTimeout = Duration(seconds: 15);

  static Future<Map<String, String>> _headers() async {
    final token = await DeviceIdentity.token();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'X-Device-Token': token,
    };
  }

  static Future<ApiResponse> get(
    String url, {
    Map<String, String>? query,
    Duration timeout = _defaultTimeout,
  }) async {
    final uri = Uri.parse(url).replace(
        queryParameters: query == null || query.isEmpty ? null : query);
    final res =
        await httpClient.get(uri, headers: await _headers()).timeout(timeout);
    return _decode(res);
  }

  static Future<ApiResponse> post(
    String url,
    Map<String, dynamic> body, {
    Duration timeout = _defaultTimeout,
  }) async {
    final res = await httpClient
        .post(Uri.parse(url), headers: await _headers(), body: jsonEncode(body))
        .timeout(timeout);
    return _decode(res);
  }

  static Future<ApiResponse> _decode(http.Response res) async {
    dynamic body;
    try {
      body = res.body.isEmpty ? null : jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      body = null;
    }
    final data = body is Map<String, dynamic> ? body : <String, dynamic>{};
    final token = data['device_token'];
    if (token is String && token.isNotEmpty) {
      await DeviceIdentity.saveToken(token);
    }
    return ApiResponse(res.statusCode, data, body is List ? body : null);
  }
}
