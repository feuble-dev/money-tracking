import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Service d'authentification biométrique
class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  /// Vérifie si la biométrie est disponible et configurée
  Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();
      if (!canCheck || !isDeviceSupported) return false;

      // Vérifier qu'il y a au moins une biométrie enregistrée
      final availableBiometrics = await _auth.getAvailableBiometrics();
      final hasEnrolled = availableBiometrics.isNotEmpty;
      debugPrint('[Biometric] canCheck=$canCheck, supported=$isDeviceSupported, '
          'enrolled=${availableBiometrics.length} ($availableBiometrics)');
      return hasEnrolled;
    } on PlatformException catch (e) {
      debugPrint('[Biometric] isAvailable error: $e');
      return false;
    }
  }

  /// Authentifie l'utilisateur par biométrie
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Authentifiez-vous pour accéder à MoneyTracking',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint('[Biometric] authenticate error: $e');
      return false;
    }
  }
}
