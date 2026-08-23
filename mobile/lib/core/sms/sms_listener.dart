import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sms_processing_pipeline.dart';

/// Provider pour l'état du service SMS
final smsServiceActiveProvider = StateProvider<bool>((ref) => false);
final lastSmsReceivedProvider = StateProvider<String?>((ref) => null);

/// Service d'écoute SMS via EventChannel natif Android
class SmsListenerService {
  static final SmsListenerService _instance = SmsListenerService._();
  factory SmsListenerService() => _instance;
  SmsListenerService._();

  static const _smsChannel = EventChannel('com.rftech.moneytracking/sms');

  ValueChanged<Map<String, dynamic>>? onTransactionDetected;
  void Function(String sender, String body)? onSmsRawReceived;
  WidgetRef? _ref;

  StreamSubscription? _subscription;
  bool _isListening = false;
  bool get isListening => _isListening;

  // Déduplication : garder les hash des SMS récents
  final _recentSmsHashes = <String>{};
  static const _maxRecentHashes = 50;

  // File d'attente séquentielle
  final _queue = <Map<String, String>>[];
  bool _processing = false;

  /// Génère un hash unique pour un SMS (sender + body tronqué)
  String _smsHash(String sender, String body) {
    return '${sender.trim()}|${body.trim().substring(0, body.trim().length.clamp(0, 100))}';
  }

  Future<void> startListening({WidgetRef? ref}) async {
    if (_isListening) return;
    _ref = ref;

    debugPrint('[SMS] ═══ Démarrage EventChannel natif ═══');

    _subscription = _smsChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          final sender = (event['sender'] as String?) ?? '';
          final body = (event['body'] as String?) ?? '';

          // DÉDUPLICATION : ignorer si déjà reçu
          final hash = _smsHash(sender, body);
          if (_recentSmsHashes.contains(hash)) {
            debugPrint('[SMS] Doublon ignoré: $sender');
            return;
          }
          _recentSmsHashes.add(hash);
          if (_recentSmsHashes.length > _maxRecentHashes) {
            _recentSmsHashes.remove(_recentSmsHashes.first);
          }

          debugPrint('[SMS] ╔═══ SMS REÇU ═══');
          debugPrint('[SMS] ║ Sender: "$sender"');
          debugPrint('[SMS] ║ Body: "${body.substring(0, body.length.clamp(0, 80))}..."');
          debugPrint('[SMS] ╚════════════════');

          _ref?.read(lastSmsReceivedProvider.notifier).state =
              '$sender: ${body.substring(0, body.length.clamp(0, 50))}...';

          onSmsRawReceived?.call(sender, body);

          _queue.add({'sender': sender, 'body': body});
          _processQueue();
        }
      },
      onError: (e) => debugPrint('[SMS] EventChannel ERREUR: $e'),
    );

    _isListening = true;
    debugPrint('[SMS] EventChannel actif');
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    _isListening = false;
    onTransactionDetected = null;
    _ref = null;
  }

  Future<void> _processQueue() async {
    if (_processing || _queue.isEmpty) return;
    _processing = true;
    while (_queue.isNotEmpty) {
      final sms = _queue.removeAt(0);
      try {
        await _handleSms(sms['sender']!, sms['body']!);
      } catch (e) {
        debugPrint('[SMS] ERREUR traitement: $e');
      }
    }
    _processing = false;
  }

  Future<void> _handleSms(String sender, String body) async {
    await processIncomingSms(sender, body, onTransactionDetected: onTransactionDetected);
  }
}
