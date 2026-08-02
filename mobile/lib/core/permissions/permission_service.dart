import 'package:permission_handler/permission_handler.dart';

/// Service centralisé de gestion des permissions Android
class PermissionService {
  /// Demande les permissions nécessaires au démarrage
  static Future<bool> requestSmsPermissions() async {
    final statuses = await [
      Permission.sms,
      Permission.phone,
    ].request();

    return statuses[Permission.sms]?.isGranted == true &&
        statuses[Permission.phone]?.isGranted == true;
  }

  /// Vérifie si les permissions SMS sont accordées
  static Future<bool> hasSmsPermissions() async {
    final sms = await Permission.sms.isGranted;
    final phone = await Permission.phone.isGranted;
    return sms && phone;
  }

  /// Demande la permission téléphone seule (pour USSD)
  static Future<bool> requestPhonePermission() async {
    final status = await Permission.phone.request();
    return status.isGranted;
  }
}
