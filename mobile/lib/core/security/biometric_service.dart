import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service d'authentification biométrique
class BiometricService {
  static const _enabledKey = 'moneytracking_biometric_enabled';
  final LocalAuthentication _auth;
  final FlutterSecureStorage _storage;

  BiometricService({LocalAuthentication? auth, FlutterSecureStorage? storage})
      : _auth = auth ?? LocalAuthentication(),
        _storage = storage ?? const FlutterSecureStorage();

  /// Vérifie si l'utilisateur a choisi d'activer le déverrouillage biométrique
  Future<bool> isEnabled() async {
    final value = await _storage.read(key: _enabledKey);
    return value == 'true';
  }

  /// Active ou désactive le déverrouillage biométrique (choix utilisateur)
  Future<void> setEnabled(bool enabled) async {
    await _storage.write(key: _enabledKey, value: enabled ? 'true' : 'false');
  }

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
