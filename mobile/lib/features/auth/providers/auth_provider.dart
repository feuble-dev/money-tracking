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

/// Provider pour vérifier la disponibilité biométrique (capacité matérielle)
final isBiometricAvailableProvider = FutureProvider<bool>((ref) async {
  final bioService = ref.read(biometricServiceProvider);
  return await bioService.isAvailable();
});

/// Provider pour vérifier si l'utilisateur a activé le déverrouillage biométrique
final isBiometricEnabledProvider = FutureProvider<bool>((ref) async {
  final bioService = ref.read(biometricServiceProvider);
  return await bioService.isEnabled();
});

/// Provider combiné : biométrie à proposer réellement (disponible ET activée par l'utilisateur)
final shouldOfferBiometricProvider = FutureProvider<bool>((ref) async {
  final available = await ref.watch(isBiometricAvailableProvider.future);
  if (!available) return false;
  return await ref.watch(isBiometricEnabledProvider.future);
});
