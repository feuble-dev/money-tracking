import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../database/caisse_repository.dart';
import '../database/database_helper.dart';
import '../database/transaction_repository.dart';
import '../licence/licence_storage.dart';
import '../notifications/notification_service.dart';
import '../sync/sync_service.dart';
import 'commission_calculator.dart';
import 'sms_field_extractor.dart';
import 'sms_matching_engine.dart';

const _uuid = Uuid();

/// Pipeline de traitement d'un SMS entrant — extrait de SmsListenerService
/// pour être appelable aussi bien depuis l'EventChannel temps réel (app au
/// premier plan/en arrière-plan mais processus vivant) que depuis l'isolate
/// headless déclenché quand l'app est totalement fermée
/// (core/sms/background_sms_handler.dart, via `another_telephony`). Une
/// seule implémentation — pas de logique dupliquée entre les deux chemins.
///
/// [onTransactionDetected] est optionnel : sans UI à rafraîchir (cas
/// headless), la transaction est simplement persistée et l'app la verra à
/// sa prochaine ouverture.
Future<void> processIncomingSms(
  String sender,
  String body, {
  ValueChanged<Map<String, dynamic>>? onTransactionDetected,
}) async {
  final db = await DatabaseHelper.instance.database;
  final now = DateTime.now();

  // 1. Vérifier si ce SMS est déjà en base (déduplication — un même SMS
  // peut être livré par plusieurs BroadcastReceivers en parallèle).
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

  // 4. Essayer CHAQUE opérateur dont le sender correspond, pas seulement le
  // premier — un sender ambigu (fuzzy LIKE ci-dessus) ne doit jamais faire
  // perdre une transaction juste parce qu'un mauvais opérateur candidat a
  // été retenu en premier et qu'aucun de ses patterns ne matche. Même
  // logique que l'import historique (historique_service.dart), qui teste
  // indépendamment chaque opérateur — c'est ce qui les rend maintenant
  // vraiment équivalents, pas seulement les deux basés sur SmsMatchingEngine.
  Map<String, Object?>? op;
  SmsMatch? smsMatch;
  for (final candidate in operators) {
    final candidateId = candidate['id'] as String;
    final patterns = await SmsMatchingEngine.loadPatternsForOperator(db, candidateId);
    final match = SmsMatchingEngine.match(body, patterns);
    if (match != null) {
      op = candidate;
      smsMatch = match;
      break;
    }
  }

  // Si aucun pattern matché chez aucun opérateur candidat → ce n'est PAS
  // une transaction, ignorer
  if (op == null || smsMatch == null) {
    debugPrint('[SMS] Aucun pattern matché — pas une transaction, ignoré');
    return;
  }
  final operatorId = op['id'] as String;
  final operatorName = op['name'] as String;
  final transactionType = smsMatch.transactionTypeCode;
  final extracted = smsMatch.extractedFields;

  final amount = SmsFieldExtractor.parseMontant(extracted['montant']);
  final clientPhone = SmsFieldExtractor.cleanPhone(extracted['numero_client']);
  if (amount == null || amount <= 0) return;
  final soldeApres = SmsFieldExtractor.parseMontant(extracted['solde']);

  // 5. Commission
  final commission = CommissionCalculator.compute(
    amount: amount,
    commissionTaux: smsMatch.commissionTaux,
  );

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

  // 7. Vérifier licence avant de créer la transaction
  final licenceStatut = await LicenceStorage.verifierLocalement();
  final peutCreer = licenceStatut == LicenceStatut.active ||
      licenceStatut == LicenceStatut.essaiActif ||
      licenceStatut == LicenceStatut.expireBientot;

  if (!peutCreer) {
    // SMS enregistré mais pas de transaction
    debugPrint('[SMS] Licence inactive — SMS enregistré sans transaction');
    await NotificationService().showPendingTransactionNotification(
      transactionId: smsId,
      type: transactionType,
      typeLabel: smsMatch.typeLabel,
      amount: amount,
      clientPhone: clientPhone ?? '',
      operatorName: 'Licence requise',
    );
    return;
  }

  // Créer la transaction (licence active)
  final txId = _uuid.v4();
  final txData = {
    'id': txId,
    'operator_id': operatorId,
    'client_id': clientId,
    'transaction_type': transactionType,
    'transaction_type_id': smsMatch.transactionTypeId,
    'direction': smsMatch.direction,
    'amount': amount,
    'commission': commission,
    'client_phone': clientPhone ?? '',
    'client_name': clientName,
    'operator_transaction_id': extracted['operator_transaction_id'],
    // Directement 'completed' — plus d'étape de confirmation manuelle pour
    // une transaction détectée par SMS (l'agent peut toujours l'annuler
    // depuis la notif ou l'écran transaction si la détection était fausse).
    'status': 'completed',
    'source': 'sms_auto',
    'sms_id': smsId,
    'sms_raw': body,
    'created_at': now.toIso8601String(),
  };
  await TransactionRepository.instance.insert(txData);

  // Met à jour le solde caisse (no-op si l'agent n'a pas initialisé de
  // caisse pour cet opérateur) — c'était auparavant fait UNIQUEMENT pour
  // les transactions créées manuellement, jamais pour la détection SMS ni
  // l'import historique, alors que ce sont l'immense majorité des
  // transactions réelles : la caisse ne reflétait donc presque jamais
  // l'activité effective. Le SMS annonce lui-même le solde réel après
  // l'opération dans la plupart des cas (`soldeApres`) — c'est la valeur
  // qu'on applique directement, pas un delta cumulé qui dériverait au
  // moindre SMS manqué.
  await CaisseRepository.updateSoldeAfterTransaction(
    operatorId: operatorId,
    amount: amount,
    direction: smsMatch.direction,
    soldeApres: soldeApres,
    transactionAt: now,
  );

  await db.update('sms_messages', {'processed': 1, 'transaction_id': txId},
      where: 'id = ?', whereArgs: [smsId]);

  final typeLabel = smsMatch.typeLabel;

  // 8. Notification selon client connu ou inconnu
  if (clientExists) {
    await NotificationService().showPendingTransactionNotification(
      transactionId: txId,
      type: transactionType,
      typeLabel: typeLabel,
      amount: amount,
      clientPhone: clientPhone ?? '',
      operatorName: '$typeLabel - $clientName',
    );
  } else {
    await NotificationService().showPendingTransactionNotification(
      transactionId: txId,
      type: transactionType,
      typeLabel: typeLabel,
      amount: amount,
      clientPhone: clientPhone ?? 'inconnu',
      operatorName: '$typeLabel - Nouveau client. Appuyez pour compléter.',
    );
  }

  onTransactionDetected?.call({...txData, 'operator_name': operatorName});
  debugPrint('[SMS] ✅ $typeLabel ${amount.toInt()} FCFA — ${clientPhone ?? "?"} ($operatorName)');

  // Pousse la nouvelle transaction vers le backend sans attendre le
  // prochain tick du timer (D-sync) — no-op immédiat si compte Particulier.
  SyncService.pushIfNeeded();
}
