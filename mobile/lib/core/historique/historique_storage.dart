import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class HistoriqueStorage {
  static const _storage = FlutterSecureStorage();
  static const _keyToken = 'mt_historique_token';

  /// Date la plus ancienne couverte par l'achat (ISO `YYYY-MM-DD`), ou
  /// [_toutHistorique] pour un achat antérieur à la tarification par période.
  static const _keyCouverture = 'mt_historique_couvert_depuis';
  static const _toutHistorique = 'all';

  /// [couvertDepuis] : date renvoyée par le backend (`date_debut_couverte`).
  /// `null` côté backend = ancien achat qui couvre tout l'historique.
  static Future<void> sauvegarderToken(String token,
      {required String? couvertDepuis}) async {
    await _storage.write(key: _keyToken, value: token);
    await _storage.write(
        key: _keyCouverture, value: couvertDepuis ?? _toutHistorique);
  }

  static Future<String?> getToken() async {
    return _storage.read(key: _keyToken);
  }

  static Future<bool> estActive() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  /// L'achat enregistré couvre-t-il un import depuis [dateDebut] ? Avant, la
  /// simple présence d'un jeton (même celui de l'import gratuit ≤ 1 an)
  /// débloquait n'importe quelle période. Un jeton sans couverture connue
  /// (installé avant cette version) répond `false` : l'écran redemande alors
  /// au backend, qui sait ce qui a été payé.
  static Future<bool> couvre(DateTime dateDebut) async {
    if (!await estActive()) return false;
    final c = await _storage.read(key: _keyCouverture);
    if (c == null) return false;
    if (c == _toutHistorique) return true;
    final depuis = DateTime.tryParse(c);
    if (depuis == null) return false;
    final jour = DateTime(dateDebut.year, dateDebut.month, dateDebut.day);
    return !jour.isBefore(depuis);
  }

  static Future<void> supprimer() async {
    await _storage.delete(key: _keyToken);
    await _storage.delete(key: _keyCouverture);
  }
}
