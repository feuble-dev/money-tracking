import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/numpad_widget.dart';
import '../../../shared/widgets/pin_dots.dart';
import '../providers/auth_provider.dart';

/// Écran de modification du code PIN
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  String _pin = '';
  bool _hasError = false;
  int _step = 0; // 0=ancien, 1=nouveau, 2=confirmer
  String _newPin = '';

  String get _title {
    switch (_step) {
      case 0:
        return 'Code PIN actuel';
      case 1:
        return 'Nouveau code PIN';
      case 2:
        return 'Confirmez le nouveau PIN';
      default:
        return '';
    }
  }

  void _onDigitPressed(int digit) {
    setState(() {
      _hasError = false;
      if (_pin.length < 4) {
        _pin += digit.toString();
        if (_pin.length == 4) {
          _processStep();
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

  Future<void> _processStep() async {
    final pinService = ref.read(pinServiceProvider);

    switch (_step) {
      case 0:
        // Vérifier l'ancien PIN
        final isValid = await pinService.verifyPin(_pin);
        if (isValid) {
          setState(() {
            _step = 1;
            _pin = '';
          });
        } else {
          setState(() {
            _hasError = true;
            _pin = '';
          });
        }
        break;
      case 1:
        // Sauvegarder le nouveau PIN temporairement
        setState(() {
          _newPin = _pin;
          _step = 2;
          _pin = '';
        });
        break;
      case 2:
        // Confirmer le nouveau PIN
        if (_pin == _newPin) {
          await pinService.setPin(_newPin);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Code PIN modifié avec succès'),
                backgroundColor: AppColors.withdrawColor,
              ),
            );
            context.pop();
          }
        } else {
          setState(() {
            _hasError = true;
            _pin = '';
            _step = 1;
            _newPin = '';
          });
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modifier le PIN')),
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
                    const Icon(Icons.lock_outline,
                        size: 48, color: AppColors.primaryColor),
                    const SizedBox(height: 12),
                    Text(_title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 20),
                    PinDots(filledCount: _pin.length, hasError: _hasError),
                    if (_hasError) ...[
                      const SizedBox(height: 8),
                      Text(
                        _step == 0 ? 'Code PIN incorrect' : 'Les codes ne correspondent pas',
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
