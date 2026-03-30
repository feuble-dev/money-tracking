import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/transaction_provider.dart';

/// Écran d'attente de confirmation SMS après lancement USSD
class SmsWaitingScreen extends ConsumerStatefulWidget {
  final String operatorName;
  final String clientPhone;
  final double amount;
  final String transactionType;

  const SmsWaitingScreen({
    super.key,
    required this.operatorName,
    required this.clientPhone,
    required this.amount,
    required this.transactionType,
  });

  @override
  ConsumerState<SmsWaitingScreen> createState() => _SmsWaitingScreenState();
}

class _SmsWaitingScreenState extends ConsumerState<SmsWaitingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  Timer? _timeoutTimer;
  int _secondsLeft = 60;
  bool _smsReceived = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Timer de compte à rebours
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _secondsLeft--;
        if (_secondsLeft <= 0) {
          timer.cancel();
        }
      });
    });

    // Écouter les transactions en attente
    _listenForSms();
  }

  void _listenForSms() {
    // Vérifier périodiquement si un SMS a été détecté
    Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final pending = ref.read(pendingTransactionsProvider);
      pending.whenData((transactions) {
        if (transactions.isNotEmpty && !_smsReceived) {
          setState(() => _smsReceived = true);
          timer.cancel();
          _timeoutTimer?.cancel();

          // Attendre un instant puis naviguer
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              context.pop(true); // Retour avec succès
            }
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isTimeout = _secondsLeft <= 0;
    final isDeposit = widget.transactionType == 'deposit';

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_smsReceived) ...[
                  const Icon(Icons.check_circle,
                      size: 80, color: AppColors.withdrawColor),
                  const SizedBox(height: 24),
                  Text(
                    'SMS de confirmation reçu !',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.withdrawColor,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ] else if (isTimeout) ...[
                  Icon(Icons.timer_off,
                      size: 80, color: Colors.orange.shade700),
                  const SizedBox(height: 24),
                  Text(
                    'Délai dépassé',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Aucun SMS de confirmation reçu.\nVous pouvez créer la transaction manuellement.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => context.pop(false),
                      icon: const Icon(Icons.edit),
                      label: const Text('Créer manuellement'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      setState(() => _secondsLeft = 60);
                      _timeoutTimer = Timer.periodic(
                          const Duration(seconds: 1), (timer) {
                        setState(() {
                          _secondsLeft--;
                          if (_secondsLeft <= 0) timer.cancel();
                        });
                      });
                    },
                    child: const Text('Attendre encore'),
                  ),
                ] else ...[
                  RotationTransition(
                    turns: _animController,
                    child: Icon(
                      Icons.sync,
                      size: 64,
                      color: isDeposit
                          ? AppColors.depositColor
                          : AppColors.withdrawColor,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'En attente de confirmation\nde l\'opérateur...',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.operatorName} — ${widget.amount.toInt()} FCFA',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  Text(widget.clientPhone,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 32),
                  // Barre de progression
                  LinearProgressIndicator(
                    value: _secondsLeft / 60,
                    backgroundColor: Colors.grey.withAlpha(30),
                    color: isDeposit
                        ? AppColors.depositColor
                        : AppColors.withdrawColor,
                  ),
                  const SizedBox(height: 8),
                  Text('${_secondsLeft}s restantes',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 32),
                  TextButton(
                    onPressed: () => context.pop(false),
                    child: const Text('Annuler l\'attente'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
