import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../permissions/permission_service.dart';

/// Lanceur de codes USSD via MethodChannel natif Android
/// Lance le USSD directement sans ouvrir l'app téléphone
class UssdLauncher {
  static const _channel = MethodChannel('com.rftech.moneytracking/ussd');

  /// Lance un code USSD directement depuis un template
  static Future<bool> launch({
    required String template,
    String? numero,
    double? montant,
  }) async {
    final hasPermission = await PermissionService.requestPhonePermission();
    if (!hasPermission) {
      debugPrint('[USSD] Permission CALL_PHONE refusée');
      return false;
    }

    String code = template;
    if (numero != null) {
      // Un numéro saisi « 70 12 34 56 » ou « +226 70… » casserait le code
      // USSD (espaces, « + ») : on n'injecte que les chiffres.
      code = code.replaceAll('{numero}', numero.replaceAll(RegExp(r'[^0-9]'), ''));
    }
    if (montant != null) {
      code = code.replaceAll('{montant}', montant.toInt().toString());
    }

    debugPrint('[USSD] Lancement direct: $code');

    try {
      final result = await _channel.invokeMethod<bool>(
        'dialUssd',
        {'code': code},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('[USSD] Erreur native: ${e.message}');
      return false;
    } catch (e) {
      debugPrint('[USSD] Erreur: $e');
      return false;
    }
  }
}
