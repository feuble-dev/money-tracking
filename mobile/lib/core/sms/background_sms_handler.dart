import 'package:another_telephony/telephony.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../notifications/notification_service.dart';
import 'sms_processing_pipeline.dart';

const _fgHeartbeatKey = 'sms_fg_heartbeat';
const _fgHeartbeatMaxAge = Duration(seconds: 90);

/// Battement de cœur écrit par l'isolate principal (main.dart) tant que l'app
/// tourne : au retour au premier plan, au démarrage de l'écoute SMS, et à
/// chaque tick du timer de sync. Permet à l'isolate headless ci-dessous de
/// savoir qu'un traitement temps réel (EventChannel) est déjà en place.
Future<void> markSmsForegroundAlive() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_fgHeartbeatKey, DateTime.now().millisecondsSinceEpoch);
}

/// Point d'entrée headless (isolate séparé, sans UI) déclenché par
/// `another_telephony` quand un SMS arrive alors que l'app est totalement
/// fermée — c'est ce qui manquait pour que la détection continue "même si
/// l'app n'est pas ouverte". Doit rester une fonction TOP-LEVEL annotée
/// `@pragma('vm:entry-point')` (contrainte du package, sinon Android ne
/// retrouve pas le callback après un kill du process).
///
/// Réutilise le même pipeline que l'écoute temps réel (EventChannel natif,
/// SmsListenerService) — aucune logique de matching/commission/licence
/// dupliquée entre les deux chemins.
@pragma('vm:entry-point')
Future<void> backgroundSmsHandler(SmsMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  final sender = message.address ?? '';
  final body = message.body ?? '';
  if (sender.isEmpty || body.isEmpty) return;

  // Chaque isolate Dart a sa propre instance de FlutterLocalNotificationsPlugin
  // — sans ré-initialisation ICI, la notification affichée par
  // processIncomingSms() (via NotificationService, plus bas) pouvait
  // échouer silencieusement dans cet isolate headless, même si le canal et
  // la permission avaient déjà été acquis depuis l'isolate principal.
  await NotificationService().initializeForBackground();

  // Le manifest déclare DEUX receivers SMS_RECEIVED (.SmsReceiver +
  // IncomingSmsReceiver d'another_telephony) : quand l'app tourne, les deux
  // se déclenchent. Si le battement de cœur est récent, l'EventChannel a
  // déjà pris ce SMS en charge dans l'isolate principal — on s'arrête ici
  // pour éviter une seconde passe complète de matching et un push sync
  // redondant. La dédup atomique de processIncomingSms (content_hash)
  // protège les données même si cette garde est franchie (app backgroundée
  // mais vivante, battement expiré, etc.).
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final hb = prefs.getInt(_fgHeartbeatKey);
    if (hb != null &&
        DateTime.now().millisecondsSinceEpoch - hb <
            _fgHeartbeatMaxAge.inMilliseconds) {
      return;
    }
  } catch (_) {}

  await processIncomingSms(sender, body);
}
