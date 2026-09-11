import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Exemption d'optimisation batterie (Doze) + écran constructeur
/// "démarrage automatique" — nécessaires ensemble sur beaucoup de
/// téléphones vendus au Burkina Faso (Tecno/Infinix/itel via Transsion,
/// Xiaomi) pour que la détection SMS survive à l'app fermée / au
/// redémarrage du téléphone (voir CLAUDE.md, section "Background SMS
/// detection"). L'exemption Doze standard seule NE SUFFIT PAS sur ces
/// surcouches constructeur : elles ont leur propre gestionnaire
/// "autostart", sans API Android standard — d'où l'écran constructeur en
/// complément (best-effort, natif, voir MainActivity.kt).
class BatteryOptimizationHelper {
  BatteryOptimizationHelper._();

  static const _channel = MethodChannel('com.rftech.moneytracking/autostart');

  static const _restrictiveManufacturers = [
    'xiaomi',
    'redmi',
    'poco',
    'transsion',
    'tecno',
    'infinix',
    'itel',
    'oppo',
    'realme',
    'vivo',
    'huawei',
    'honor',
    'samsung',
  ];

  static Future<bool> hasExemption() async {
    return Permission.ignoreBatteryOptimizations.status
        .then((s) => s.isGranted);
  }

  /// `true` si le fabricant de l'appareil est connu pour avoir son propre
  /// gestionnaire "autostart" en plus de Doze — sert à décider si on
  /// propose l'écran constructeur en complément.
  static Future<bool> isKnownRestrictiveManufacturer() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final manufacturer = info.manufacturer.toLowerCase();
      return _restrictiveManufacturers.any(manufacturer.contains);
    } catch (_) {
      return false;
    }
  }

  /// Explique puis demande l'exemption Doze. Renvoie `true` si déjà
  /// accordée ou accordée suite à la demande, `false` sinon (y compris si
  /// l'utilisateur choisit "Plus tard").
  static Future<bool> requestExemption(BuildContext context) async {
    if (await hasExemption()) return true;
    if (!context.mounted) return false;

    final confirme = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fonctionnement en arrière-plan'),
        content: const Text(
          'Pour que MoneyTracking détecte vos SMS même quand l\'app est '
          'fermée, Android doit être autorisé à ne pas la mettre en veille '
          'forcée. Sans ça, certains téléphones (Xiaomi, Tecno, Infinix, '
          'Samsung...) coupent la détection après quelques minutes.\n\n'
          'L\'écran suivant vient d\'Android — choisissez "Autoriser" ou '
          '"Ne pas optimiser".',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Plus tard')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuer')),
        ],
      ),
    );
    if (confirme != true) return false;

    final resultat = await Permission.ignoreBatteryOptimizations.request();
    return resultat.isGranted;
  }

  /// Tente d'ouvrir l'écran "démarrage automatique" du constructeur (best-
  /// effort natif, voir MainActivity.kt) ; si aucun écran connu ne s'ouvre,
  /// retombe sur la page Paramètres de l'app (toujours disponible), d'où
  /// l'utilisateur peut au moins atteindre "Batterie"/"Applications"
  /// manuellement.
  static Future<void> openAutostartSettings() async {
    try {
      final opened = await _channel.invokeMethod<bool>('openAutostartSettings');
      if (opened == true) return;
    } catch (_) {}
    await openAppSettings();
  }
}
