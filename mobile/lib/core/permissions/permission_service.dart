import 'package:permission_handler/permission_handler.dart';

/// Service centralisé de gestion des permissions Android
class PermissionService {
  /// Demande les permissions nécessaires au démarrage. Ne redemande jamais
  /// une permission déjà accordée, et ne relance pas le popup système si
  /// l'utilisateur a définitivement refusé (`permanentlyDenied`) — dans ce
  /// cas seul un passage par les réglages système (`openAppSettings()`) peut
  /// la débloquer.
  static Future<bool> requestSmsPermissions() async {
    final toRequest = <Permission>[];
    for (final p in [Permission.sms, Permission.phone]) {
      final status = await p.status;
      if (!status.isGranted && !status.isPermanentlyDenied) {
        toRequest.add(p);
      }
    }
    if (toRequest.isNotEmpty) {
      await toRequest.request();
    }
    return hasSmsPermissions();
  }

  /// Vérifie si les permissions SMS sont accordées
  static Future<bool> hasSmsPermissions() async {
    final sms = await Permission.sms.isGranted;
    final phone = await Permission.phone.isGranted;
    return sms && phone;
  }

  /// Vrai si SMS ou téléphone ont été refusés définitivement — seul un
  /// passage par les réglages système peut alors débloquer la détection.
  static Future<bool> isSmsPermanentlyDenied() async {
    final sms = await Permission.sms.status;
    final phone = await Permission.phone.status;
    return sms.isPermanentlyDenied || phone.isPermanentlyDenied;
  }

  /// Demande la permission téléphone seule (pour USSD)
  static Future<bool> requestPhonePermission() async {
    final status = await Permission.phone.request();
    return status.isGranted;
  }

  /// Demande la permission contacts (sélection du numéro client au
  /// lancement d'un USSD). Ne relance pas le popup système si l'utilisateur
  /// a définitivement refusé — l'appelant retombe alors sur la saisie
  /// manuelle du numéro.
  static Future<bool> requestContactsPermission() async {
    final status = await Permission.contacts.status;
    if (status.isGranted) return true;
    if (status.isPermanentlyDenied) return false;
    return (await Permission.contacts.request()).isGranted;
  }
}
