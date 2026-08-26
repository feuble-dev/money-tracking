import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../../../shared/widgets/pin_dots.dart';
import '../../../shared/widgets/numpad_widget.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/security/biometric_service.dart';

/// Écran de création du PIN initial
class SetupPinScreen extends ConsumerStatefulWidget {
  const SetupPinScreen({super.key});

  @override
  ConsumerState<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends ConsumerState<SetupPinScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _hasError = false;
  String _errorMessage = '';

  void _onDigitPressed(int digit) {
    setState(() {
      _hasError = false;
      if (!_isConfirming) {
        if (_pin.length < 4) {
          _pin += digit.toString();
          if (_pin.length == 4) {
            // Passer à la confirmation
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _isConfirming = true;
                });
              }
            });
          }
        }
      } else {
        if (_confirmPin.length < 4) {
          _confirmPin += digit.toString();
          if (_confirmPin.length == 4) {
            _validatePin();
          }
        }
      }
    });
  }

  void _onDeletePressed() {
    setState(() {
      _hasError = false;
      if (!_isConfirming) {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      } else {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      }
    });
  }

  Future<void> _validatePin() async {
    if (_pin == _confirmPin) {
      final pinService = ref.read(pinServiceProvider);
      await pinService.setPin(_pin);

      final bioService = ref.read(biometricServiceProvider);
      if (await bioService.isAvailable() && mounted) {
        await _askEnableBiometric(bioService);
      }

      // Rafraîchir isPinSet pour que le router redirige vers le dashboard
      ref.invalidate(isPinSetProvider);
      ref.read(isAuthenticatedProvider.notifier).state = true;
    } else {
      setState(() {
        _hasError = true;
        _errorMessage = 'Les codes PIN ne correspondent pas';
        _confirmPin = '';
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _hasError = false;
            _isConfirming = false;
            _pin = '';
          });
        }
      });
    }
  }

  Future<void> _askEnableBiometric(BiometricService bioService) async {
    final activer = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Déverrouillage par empreinte ?'),
        content: const Text(
          'Une empreinte digitale est configurée sur cet appareil. '
          'Voulez-vous l\'utiliser pour déverrouiller MoneyTracking ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Oui'),
          ),
        ],
      ),
    );
    await bioService.setEnabled(activer ?? false);
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _isConfirming ? _confirmPin : _pin;

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
                      Icons.phone_android,
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
                      _isConfirming
                          ? 'Confirmez votre code PIN'
                          : 'Créez votre code PIN',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 20),
                    PinDots(filledCount: currentPin.length, hasError: _hasError),
                    if (_hasError) ...[
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red, fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 24),
                    NumpadWidget(
                      onDigitPressed: _onDigitPressed,
                      onDeletePressed: _onDeletePressed,
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
