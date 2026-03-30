import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../database/transaction_repository.dart';
import '../notifications/notification_service.dart';
import 'sms_field_extractor.dart';

/// Provider pour l'état du service SMS
final smsServiceActiveProvider = StateProvider<bool>((ref) => false);
final lastSmsReceivedProvider = StateProvider<String?>((ref) => null);

/// Service d'écoute SMS via EventChannel natif Android
class SmsListenerService {
  static final SmsListenerService _instance = SmsListenerService._();
  factory SmsListenerService() => _instance;
  SmsListenerService._();

  static const _smsChannel = EventChannel('com.rftech.moneytracking/sms');
  final _uuid = const Uuid();

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
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now();

    // 1. Vérifier si ce SMS est déjà en base (déduplication DB)
    final existing = await db.query('sms_messages',
      where: 'sender = ? AND body = ? AND received_at > ?',
      whereArgs: [sender, body, now.subtract(const Duration(minutes: 2)).toIso8601String()],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      debugPrint('[SMS] Déjà en base, ignoré');
      return;
    }

    // 2. Enregistrer le SMS
    final smsId = _uuid.v4();
    await db.insert('sms_messages', {
      'id': smsId,
      'sender': sender,
      'body': body,
      'received_at': now.toIso8601String(),
      'processed': 0,
      'created_at': now.toIso8601String(),
    });

    // 3. Chercher l'opérateur par sender
    var operators = await db.query('operators',
      where: 'LOWER(sms_sender) = LOWER(?) AND is_active = 1',
      whereArgs: [sender.trim()],
    );
    if (operators.isEmpty) {
      operators = await db.rawQuery('''
        SELECT * FROM operators
        WHERE is_active = 1 AND sms_sender IS NOT NULL AND sms_sender != ''
          AND (LOWER(?) LIKE '%' || LOWER(sms_sender) || '%'
               OR LOWER(sms_sender) LIKE '%' || LOWER(?) || '%')
      ''', [sender.trim(), sender.trim()]);
    }

    if (operators.isEmpty) {
      debugPrint('[SMS] Aucun opérateur pour: "$sender"');
      return;
    }

    final op = operators.first;
    final operatorId = op['id'] as String;
    final operatorName = op['name'] as String;

    // 4. Extraire les champs
    final extracted = SmsFieldExtractor.extractAll(body);
    if (!extracted.containsKey('montant')) {
      debugPrint('[SMS] Pas de montant détecté');
      return;
    }

    final amount = SmsFieldExtractor.parseMontant(extracted['montant']);
    final clientPhone = SmsFieldExtractor.cleanPhone(extracted['numero_client']);
    if (amount == null || amount <= 0) return;

    final transactionType = SmsFieldExtractor.detectTransactionType(body);
    if (transactionType == null) return;

    // 5. Commission
    final tauxDep = (op['taux_commission_depot'] as num?)?.toDouble() ?? 0;
    final tauxRet = (op['taux_commission_retrait'] as num?)?.toDouble() ?? 0;
    final commission = (amount * (transactionType == 'deposit' ? tauxDep : tauxRet)) / 100;

    // 6. Chercher le client
    String? clientId;
    String? clientName = extracted['nom_client'];
    bool clientExists = false;

    if (clientPhone != null && clientPhone.isNotEmpty) {
      final clients = await db.query('clients',
          where: 'phone_number = ?', whereArgs: [clientPhone]);
      if (clients.isNotEmpty) {
        clientId = clients.first['id'] as String;
        clientName ??= '${clients.first['first_name']} ${clients.first['last_name']}';
        clientExists = true;
      }
    }

    // 7. Créer la transaction (TOUJOURS — c'est le SMS qui crée)
    final txId = _uuid.v4();
    final txData = {
      'id': txId,
      'operator_id': operatorId,
      'client_id': clientId,
      'transaction_type': transactionType,
      'amount': amount,
      'commission': commission,
      'client_phone': clientPhone ?? '',
      'client_name': clientName,
      'operator_transaction_id': extracted['operator_transaction_id'],
      'status': 'pending',
      'source': 'sms_auto',
      'sms_id': smsId,
      'sms_raw': body,
      'created_at': now.toIso8601String(),
    };
    await TransactionRepository.instance.insert(txData);

    await db.update('sms_messages', {'processed': 1, 'transaction_id': txId},
        where: 'id = ?', whereArgs: [smsId]);

    final typeLabel = transactionType == 'deposit' ? 'Dépôt' : 'Retrait';

    // 8. Notification selon client connu ou inconnu
    if (clientExists) {
      // Client connu → notification simple
      await NotificationService().showPendingTransactionNotification(
        transactionId: txId,
        type: transactionType,
        amount: amount,
        clientPhone: clientPhone ?? '',
        operatorName: '$typeLabel — $clientName',
      );
    } else {
      // Client INCONNU → notification invite à créer le client
      // Le payload contient l'ID transaction pour ouvrir le formulaire client
      await NotificationService().showPendingTransactionNotification(
        transactionId: txId,
        type: transactionType,
        amount: amount,
        clientPhone: clientPhone ?? 'inconnu',
        operatorName: '$typeLabel — Nouveau client. Appuyez pour compléter.',
      );
    }

    onTransactionDetected?.call({...txData, 'operator_name': operatorName});
    debugPrint('[SMS] ✅ $typeLabel ${amount.toInt()} FCFA — ${clientPhone ?? "?"} ($operatorName)');
  }
}
