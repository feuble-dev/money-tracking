import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/pin_service.dart';
import '../../../core/security/biometric_service.dart';

/// Provider pour le service PIN
final pinServiceProvider = Provider<PinService>((ref) => PinService());

/// Provider pour le service biométrique
final biometricServiceProvider =
    Provider<BiometricService>((ref) => BiometricService());

/// Provider pour l'état d'authentification
final isAuthenticatedProvider = StateProvider<bool>((ref) => false);

/// Provider pour vérifier si le PIN est configuré
final isPinSetProvider = FutureProvider<bool>((ref) async {
  final pinService = ref.read(pinServiceProvider);
  return await pinService.isPinSet();
});

/// Provider pour vérifier la disponibilité biométrique
final isBiometricAvailableProvider = FutureProvider<bool>((ref) async {
  final bioService = ref.read(biometricServiceProvider);
  return await bioService.isAvailable();
});
