import 'package:another_telephony/telephony.dart';
import 'package:flutter/widgets.dart';
import 'sms_processing_pipeline.dart';

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
  await processIncomingSms(sender, body);
}
