import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Identité de CETTE installation de l'app auprès du backend.
///
/// - [id] : identifiant stable. Les anciennes versions envoyaient
///   `Build.ID` (numéro de firmware, identique sur tous les téléphones d'un
///   même modèle à jour) — il est conservé pour les installations
///   existantes (leurs licences y sont liées côté serveur), mais toute
///   NOUVELLE installation reçoit un UUID aléatoire.
/// - [token] : secret émis par le serveur (création de compte, connexion,
///   demande d'affiliation, ou migration d'une ancienne installation),
///   présenté dans l'en-tête `X-Device-Token`. Le `device_id` seul ne prouve
///   plus rien.
class DeviceIdentity {
  DeviceIdentity._();

  static const _storage = FlutterSecureStorage();
  static const _kId = 'mt_device_id';
  static const _kToken = 'mt_device_token';

  static String? _id;
  static String? _token;
  static bool _tokenLoaded = false;

  /// Indique, à la première résolution de l'id, si l'app était déjà
  /// installée avant cette version (licence ou téléphone déjà enregistrés).
  @visibleForTesting
  static Future<bool> Function() isLegacyInstall = _defaultIsLegacy;

  static Future<bool> _defaultIsLegacy() async =>
      await _storage.read(key: 'mt_licence') != null ||
      await _storage.read(key: 'mt_telephone') != null;

  static Future<String> id() async {
    if (_id != null) return _id!;
    var stored = await _storage.read(key: _kId);
    if (stored == null || stored.isEmpty) {
      stored = await isLegacyInstall()
          ? (await DeviceInfoPlugin().androidInfo).id
          : const Uuid().v4();
      await _storage.write(key: _kId, value: stored);
    }
    return _id = stored;
  }

  static Future<String?> token() async {
    if (_tokenLoaded) return _token;
    _token = await _storage.read(key: _kToken);
    _tokenLoaded = true;
    return _token;
  }

  static Future<void> saveToken(String token) async {
    await _storage.write(key: _kToken, value: token);
    _token = token;
    _tokenLoaded = true;
  }

  static Future<bool> hasToken() async => (await token())?.isNotEmpty ?? false;

  @visibleForTesting
  static void resetCache() {
    _id = null;
    _token = null;
    _tokenLoaded = false;
  }
}
