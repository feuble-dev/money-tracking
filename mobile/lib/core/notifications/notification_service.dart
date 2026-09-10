import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../database/transaction_repository.dart';

/// Action sur les notifications — une transaction détectée par SMS est
/// créée directement 'completed' (plus d'étape de confirmation), seule
/// l'annulation reste une action pertinente depuis la notification.
const _actionReject = 'REJECT';

/// Compte Particulier : bouton « Catégoriser » qui ouvre l'app sur l'écran
/// de catégorisation rapide de cette transaction (D-catégories).
const _actionCategorize = 'CATEGORIZE';

/// Service de notifications locales MoneyTracking
/// Avec un bouton Annuler directement dans la notif (la transaction
/// détectée par SMS est déjà enregistrée, pas en attente de confirmation)
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

    // Android 13+ (API 33) exige une permission d'exécution explicite pour
    // afficher la moindre notification — sans cet appel, toutes les notifs
    // ci-dessous échouaient silencieusement sur les appareils récents.
    await androidPlugin?.requestNotificationsPermission();
  }

  /// Gère la réponse à une notification (tap ou bouton d'action)
  void _handleNotificationResponse(NotificationResponse response) {
    final payload = response.payload;
    final actionId = response.actionId;

    debugPrint('[NOTIF] Response: action=$actionId, payload=$payload');

    if (actionId == _actionReject && payload != null) {
      final transactionId = _stripPrefix(payload);
      _rejectTransaction(transactionId);
    } else {
      // Tap simple, ou bouton « Catégoriser » (showsUserInterface) → laisse
      // main.dart router selon le préfixe du payload ('tx:<id>' → la
      // transaction, 'cat:<id>' → catégorisation rapide, sinon → la liste).
      onNotificationTapped?.call(payload);
    }
  }

  static String _stripPrefix(String payload) {
    final i = payload.indexOf(':');
    return i >= 0 ? payload.substring(i + 1) : payload;
  }

  /// Annuler une transaction directement depuis la notification (ex: SMS
  /// mal détecté) — la transaction est déjà 'completed' à la création,
  /// il n'y a plus d'étape de confirmation à faire, seulement une
  /// éventuelle correction.
  Future<void> _rejectTransaction(String transactionId) async {
    try {
      await TransactionRepository.instance.reject(transactionId);
      debugPrint('[NOTIF] Transaction rejetée: $transactionId');
      onActionPerformed?.call();
    } catch (e) {
      debugPrint('[NOTIF] Erreur rejet: $e');
    }
  }

  /// Afficher une notification avec un bouton Annuler — la transaction a
  /// déjà été créée 'completed' au moment de l'appel (voir
  /// sms_processing_pipeline.dart), donc "Confirmer" n'a plus de sens ici.
  Future<void> showPendingTransactionNotification({
    required String transactionId,
    required String type,
    required double amount,
    required String clientPhone,
    required String operatorName,
    String? typeLabel,
    // Compte Particulier + dépense non encore catégorisée : la notif invite
    // à catégoriser (bouton + tap qui ouvre l'écran de catégorisation
    // rapide) plutôt que « compléter les infos client » (D18).
    bool offerCategorize = false,
  }) async {
    // typeLabel permet d'afficher le libellé réel du type (ex: "Transfert")
    // pour les types au-delà de dépôt/retrait — sinon repli binaire.
    typeLabel ??= type == 'deposit' ? 'Dépôt' : 'Retrait';
    final amountStr = '${amount.toInt()} FCFA';

    final actions = <AndroidNotificationAction>[
      if (offerCategorize)
        const AndroidNotificationAction(
          _actionCategorize,
          'Catégoriser',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      const AndroidNotificationAction(
        _actionReject,
        'Annuler',
        showsUserInterface: false,
        cancelNotification: true,
      ),
    ];

    await _plugin.show(
      transactionId.hashCode,
      'MoneyTracking - $typeLabel enregistré',
      '$amountStr - $clientPhone ($operatorName)',
      NotificationDetails(
        android: AndroidNotificationDetails(
          'mobitracking_sms',
          'Transactions SMS',
          channelDescription: 'Notifications de transactions détectées par SMS',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          actions: actions,
        ),
      ),
      payload: offerCategorize ? 'cat:$transactionId' : 'tx:$transactionId',
    );
  }

  /// Récapitulatif mensuel (compte Particulier) — affiché une fois par mois
  /// au démarrage, résume les dépenses du mois écoulé. Tap → écran Budget.
  Future<void> showMonthlySummary({
    required String title,
    required String body,
  }) async {
    await _plugin.show(
      920001,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'mobitracking_general',
          'Notifications générales',
          channelDescription: 'Notifications envoyées par l\'administrateur',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(''),
        ),
      ),
      payload: 'summary',
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
      payload: 'general',
    );
  }
}
