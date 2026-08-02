import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HistoriqueStorage {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'mt_historique_token';

  static Future<void> sauvegarderToken(String token) async {
    await _storage.write(key: _keyToken, value: token);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _keyToken);
  }

  static Future<bool> estActive() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> supprimer() async {
    await _storage.delete(key: _keyToken);
  }
}
