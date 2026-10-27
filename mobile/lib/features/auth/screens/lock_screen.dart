import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/pin_dots.dart';
import '../../../shared/widgets/numpad_widget.dart';
import '../../../core/theme/app_colors.dart';

/// Écran de verrouillage — saisie PIN + biométrie
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  bool _hasError = false;

  /// Secondes restantes de blocage après trop d'erreurs (0 = libre).
  int _lockSeconds = 0;
  Timer? _lockTimer;

  @override
  void initState() {
    super.initState();
    // Attendre que le widget soit complètement monté
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshLock();
      _tryBiometric();
    });
  }

  @override
  void dispose() {
    _lockTimer?.cancel();
    super.dispose();
  }

  /// Relit le blocage persisté et lance le compte à rebours affiché.
  Future<void> _refreshLock() async {
    final left = await ref.read(pinServiceProvider).lockRemaining();
    if (!mounted) return;
    _lockTimer?.cancel();
    setState(() => _lockSeconds = left.inSeconds + (left.inMilliseconds % 1000 > 0 ? 1 : 0));
    if (_lockSeconds <= 0) return;
    _lockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _lockSeconds--);
      if (_lockSeconds <= 0) t.cancel();
    });
  }

  /// Tente l'authentification biométrique au démarrage
  Future<void> _tryBiometric() async {
    if (!mounted) return;
    try {
      final bioService = ref.read(biometricServiceProvider);
      final shouldOffer = await ref.read(shouldOfferBiometricProvider.future);
      debugPrint('[BIO] shouldOffer=$shouldOffer');
      if (shouldOffer && mounted) {
        final success = await bioService.authenticate();
        debugPrint('[BIO] authenticate=$success');
        if (success && mounted) {
          ref.read(isAuthenticatedProvider.notifier).state = true;
        }
      }
    } catch (e) {
      debugPrint('[BIO] Erreur: $e');
    }
  }

  void _onDigitPressed(int digit) {
    if (_lockSeconds > 0) return;
    setState(() {
      _hasError = false;
      if (_pin.length < 4) {
        _pin += digit.toString();
        if (_pin.length == 4) {
          _verifyPin();
        }
      }
    });
  }

  void _onDeletePressed() {
    setState(() {
      _hasError = false;
      if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _verifyPin() async {
    final pinService = ref.read(pinServiceProvider);
    final isValid = await pinService.verifyPin(_pin);
    if (isValid) {
      ref.read(isAuthenticatedProvider.notifier).state = true;
    } else {
      setState(() {
        _hasError = true;
        _pin = '';
      });
      await _refreshLock();
    }
  }

  @override
  Widget build(BuildContext context) {
    final biometricAvailable = ref.watch(shouldOfferBiometricProvider);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 24),
                    const Icon(
                      Icons.lock_outline,
                      size: 56,
                      color: AppColors.primaryColor,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'MoneyTracking',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Entrez votre code PIN',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 20),
                    PinDots(filledCount: _pin.length, hasError: _hasError),
                    if (_lockSeconds > 0) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Trop d\'essais. Réessayez dans $_lockSeconds s',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ] else if (_hasError) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'Code PIN incorrect',
                        style: TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 24),
                    NumpadWidget(
                      onDigitPressed: _onDigitPressed,
                      onDeletePressed: _onDeletePressed,
                      bottomLeftWidget: biometricAvailable.when(
                        data: (available) => available
                            ? IconButton(
                                onPressed: _tryBiometric,
                                icon: const Icon(Icons.fingerprint, size: 36),
                                color: AppColors.primaryColor,
                              )
                            : null,
                        loading: () => null,
                        error: (_, _) => null,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
