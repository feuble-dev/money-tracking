import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Avatar réutilisable pour afficher le logo d'un opérateur.
/// `logoPath` peut être soit un chemin de fichier LOCAL (opérateur custom,
/// logo choisi via file_picker — voir OperatorFormScreen._pickLogo), soit
/// une URL distante HTTP(S) (opérateur importé du catalogue admin —
/// CatalogSyncService, logoUrl vient tel quel de la réponse API). Les deux
/// cas partagent la même colonne `operators.logo_path`, donc il faut
/// distinguer au rendu plutôt qu'à l'import.
class OperatorAvatar extends StatelessWidget {
  final String name;
  final String? logoPath;
  final double radius;

  const OperatorAvatar({
    super.key,
    required this.name,
    this.logoPath,
    this.radius = 16,
  });

  /// `File.existsSync()` est un appel disque synchrone : sans cache, chaque
  /// ligne de liste en refaisait un à chaque reconstruction. Un logo ne
  /// disparaît pas en cours de session ; si c'était le cas, l'errorBuilder
  /// de l'image retombe sur l'initiale.
  /// Seuls les fichiers trouvés sont mémorisés : un logo pas encore
  /// téléchargé (resync en cours) doit pouvoir apparaître au rendu suivant.
  static final Set<String> _existing = {};

  static bool _fileExists(String path) {
    if (_existing.contains(path)) return true;
    final found = File(path).existsSync();
    if (found) _existing.add(path);
    return found;
  }

  bool get _isRemoteUrl =>
      logoPath != null &&
      (logoPath!.startsWith('http://') || logoPath!.startsWith('https://'));

  @override
  Widget build(BuildContext context) {
    final isRemote = _isRemoteUrl;
    final isLocalFile =
        !isRemote && logoPath != null && _fileExists(logoPath!);
    final hasLogo = isRemote || isLocalFile;

    final fallback = Text(
      name.isNotEmpty ? name[0].toUpperCase() : '?',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        color: AppColors.primaryColor,
        fontSize: radius * 0.85,
      ),
    );

    if (!hasLogo) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppColors.primaryColor.withAlpha(20),
        child: fallback,
      );
    }

    if (isRemote) {
      // Image.network gère nativement le cache mémoire + le fallback via
      // errorBuilder (ex: logo supprimé côté serveur, pas de réseau) —
      // CircleAvatar.backgroundImage n'a pas de errorBuilder équivalent.
      return ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: Image.network(
            logoPath!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                color: AppColors.primaryColor.withAlpha(20),
                alignment: Alignment.center,
                child: SizedBox(
                  width: radius * 0.8,
                  height: radius * 0.8,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) => Container(
              color: AppColors.primaryColor.withAlpha(20),
              alignment: Alignment.center,
              child: fallback,
            ),
          ),
        ),
      );
    }

    // Décodé à la taille affichée, pas en pleine résolution : un logo de
    // 1024 px pour un avatar de 32 px gaspillait mémoire et temps de rendu.
    final px = (radius * 2 * MediaQuery.devicePixelRatioOf(context)).round();
    return ClipOval(
      child: Image.file(
        File(logoPath!),
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        cacheWidth: px,
        errorBuilder: (context, error, stackTrace) => CircleAvatar(
          radius: radius,
          backgroundColor: AppColors.primaryColor.withAlpha(20),
          child: fallback,
        ),
      ),
    );
  }
}
