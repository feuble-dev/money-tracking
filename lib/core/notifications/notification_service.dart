import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database/database_helper.dart';
import '../database/transaction_repository.dart';

/// Actions sur les notifications
const _actionConfirm = 'CONFIRM';
const _actionReject = 'REJECT';

/// Service de notifications locales MoneyTracking
/// Avec boutons d'action Confirmer / Rejeter directement dans la notif
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Callback quand l'utilisateur tape sur la notification (ouvre l'app)
  void Function(String? transactionId)? onNotificationTapped;

  /// Callback quand une action est effectuée (pour rafraîchir l'UI)
  VoidCallback? onActionPerformed;

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const initSettings = InitializationSettings(android: androidSettings);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
    );

    // Créer le canal avec les actions
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    const channel = AndroidNotificationChannel(
      'mobitracking_sms',
      'Transactions SMS',
      description: 'Notifications de transactions détectées par SMS',
      importance: Importance.high,
    );
    await androidPlugin?.createNotificationChannel(channel);
  }

  /// Gère la réponse à une notification (tap ou bouton d'action)
  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;

    debugPrint('[NOTIF] Response: action=$actionId, payload=$payload');

    if (actionId == _actionConfirm && payload != null) {
      _confirmTransaction(payload);
    } else if (actionId == _actionReject && payload != null) {
      _rejectTransaction(payload);
    } else {
      // Tap simple sur la notification → ouvrir la page notifications
      onNotificationTapped?.call(payload);
    }
  }

  /// Confirmer une transaction directement depuis la notification
  Future<void> _confirmTransaction(String transactionId) async {
    try {
      final db = await DatabaseHelper.instance.database;
      await db.update('transactions', {'status': 'completed'},
          where: 'id = ?', whereArgs: [transactionId]);
      debugPrint('[NOTIF] Transaction confirmée: $transactionId');
      onActionPerformed?.call();
    } catch (e) {
      debugPrint('[NOTIF] Erreur confirmation: $e');
    }
  }

  /// Rejeter/annuler une transaction directement depuis la notification
  Future<void> _rejectTransaction(String transactionId) async {
    try {
      await TransactionRepository.instance.reject(transactionId);
      debugPrint('[NOTIF] Transaction rejetée: $transactionId');
      onActionPerformed?.call();
    } catch (e) {
      debugPrint('[NOTIF] Erreur rejet: $e');
    }
  }

  /// Afficher une notification avec boutons Confirmer / Rejeter
  Future<void> showPendingTransactionNotification({
    required String transactionId,
    required String type,
    required double amount,
    required String clientPhone,
    required String operatorName,
  }) async {
    final typeLabel = type == 'deposit' ? 'Dépôt' : 'Retrait';
    final amountStr = '${amount.toInt()} FCFA';

    await _plugin.show(
      transactionId.hashCode,
      'MoneyTracking — $typeLabel détecté',
      '$amountStr — $clientPhone ($operatorName)',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'mobitracking_sms',
          'Transactions SMS',
          channelDescription: 'Notifications de transactions détectées par SMS',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          actions: const [
            AndroidNotificationAction(
              _actionConfirm,
              'Confirmer',
              showsUserInterface: false,
              cancelNotification: true,
            ),
            AndroidNotificationAction(
              _actionReject,
              'Rejeter',
              showsUserInterface: false,
              cancelNotification: true,
            ),
          ],
        ),
      ),
      payload: transactionId,
    );
  }

  /// Notification générale (envoyée par l'admin)
  Future<void> showGeneralNotification({
    required int id,
    required String titre,
    required String message,
  }) async {
    await _plugin.show(
      id + 100000, // offset pour éviter collision avec les IDs transaction
      titre,
      message,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mobitracking_general',
          'Notifications générales',
          channelDescription: 'Notifications envoyées par l\'administrateur',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }
}
