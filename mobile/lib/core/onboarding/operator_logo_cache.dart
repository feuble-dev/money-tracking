import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Télécharge et met en cache localement les logos des opérateurs importés du
/// catalogue admin.
///
/// Avant : `operators.logo_path` contenait l'URL distante du logo, rechargée
/// depuis le serveur à chaque affichage (`OperatorAvatar` → `Image.network`).
/// Maintenant : le fichier est téléchargé une seule fois dans
/// `<appDocs>/operator_logos/` (le même dossier que les logos custom choisis
/// via `OperatorFormScreen._pickLogo`), `logo_path` pointe sur ce fichier
/// local et `operators.logo_url` conserve l'URL source pour détecter un
/// changement de logo au resync catalogue (D6).
class OperatorLogoCache {
  static Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'operator_logos'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Nom de fichier stable (sans extension) pour un opérateur catalogue.
  static String _stem(int catalogOperatorId) => 'op_cat_$catalogOperatorId';

  /// Télécharge [url] et l'écrit dans un fichier local nommé d'après
  /// [catalogOperatorId]. Retourne le chemin local, ou `null` si le
  /// téléchargement échoue — l'appelant garde alors l'URL distante en base
  /// (`OperatorAvatar` sait toujours l'afficher en secours) et un prochain
  /// resync retentera.
  static Future<String?> fetch(String url, int catalogOperatorId) async {
    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode != 200 || resp.bodyBytes.isEmpty) return null;

      var ext = p.extension(Uri.parse(url).path).toLowerCase();
      if (ext.isEmpty || ext.length > 5) ext = '.png';

      final dir = await _dir();
      // Purge une éventuelle version précédente (extension différente incluse).
      await remove(catalogOperatorId);

      final file = File(p.join(dir.path, '${_stem(catalogOperatorId)}$ext'));
      await file.writeAsBytes(resp.bodyBytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Supprime le logo caché d'un opérateur catalogue.
  static Future<void> remove(int catalogOperatorId) async {
    try {
      final dir = await _dir();
      final stem = _stem(catalogOperatorId);
      for (final f in dir.listSync()) {
        if (f is File && p.basenameWithoutExtension(f.path) == stem) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }
}
