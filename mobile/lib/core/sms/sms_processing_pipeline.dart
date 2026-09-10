import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/caisse_repository.dart';
import '../database/database_helper.dart';
import '../database/transaction_repository.dart';
import '../licence/licence_storage.dart';
import '../notifications/notification_service.dart';
import '../sync/sync_service.dart';
import 'commission_calculator.dart';
import 'sms_dedup.dart';
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
  // Date réelle de réception du SMS — passée explicitement par le
  // rattrapage au démarrage (sms_catchup_service.dart) pour un SMS lu
  // depuis la boîte de réception plutôt que reçu à l'instant. Par défaut
  // "maintenant", pour les deux chemins temps réel (EventChannel + isolate
  // headless) qui traitent bien un SMS qui vient d'arriver.
  DateTime? receivedAt,
}) async {
  final db = await DatabaseHelper.instance.database;
  final now = receivedAt ?? DateTime.now();

  // 1+2. Enregistrer le SMS avec déduplication ATOMIQUE. Le même SMS peut
  // être livré en parallèle par deux BroadcastReceivers (EventChannel dans
  // l'isolate principal + isolate headless another_telephony), chacun avec
  // sa propre connexion SQLite : un "SELECT puis INSERT" séparé n'est pas
  // atomique entre isolates et laissait les deux créer une ligne + une
  // transaction. L'index UNIQUE sur content_hash + ConflictAlgorithm.ignore
  // fait de l'INSERT le point de sérialisation — insert() renvoie 0 quand la
  // ligne est rejetée, donc un autre chemin l'a déjà prise en charge.
  final smsId = _uuid.v4();
  final inserted = await db.insert('sms_messages', {
    'id': smsId,
    'sender': sender,
    'body': body,
    'received_at': now.toIso8601String(),
    'processed': 0,
    'content_hash': smsContentHash(sender, body),
    'created_at': now.toIso8601String(),
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
  if (inserted == 0) {
    debugPrint('[SMS] Doublon (empreinte identique) — ignoré');
    return;
  }

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

  // Filet secondaire : si le SMS porte une référence de transaction
  // opérateur déjà connue pour cet opérateur, ne pas recréer de transaction
  // (même dédup que l'import historique — historique_service.dart). Couvre
  // le même paiement annoncé par deux SMS distincts, ou un recoupement
  // temps réel / import.
  final opTxRef = extracted['operator_transaction_id'];
  if (opTxRef != null && opTxRef.isNotEmpty) {
    final dup = await db.query('transactions',
        where: 'operator_transaction_id = ? AND operator_id = ?',
        whereArgs: [opTxRef, operatorId],
        limit: 1);
    if (dup.isNotEmpty) {
      await db.update('sms_messages',
          {'processed': 1, 'transaction_id': dup.first['id']},
          where: 'id = ?', whereArgs: [smsId]);
      debugPrint('[SMS] Réf transaction déjà connue ($opTxRef) — pas de doublon');
      return;
    }
  }

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
    // 'completed' directement pour un match exact ou flou à haute confiance
    // (>= SmsMatchingEngine.autoCreateMin) — pas d'étape de confirmation
    // manuelle dans ce cas (l'agent peut toujours annuler depuis la notif
    // ou l'écran transaction si la détection était fausse). En dessous
    // (match flou 60-79%, formulation d'opérateur qui ne matchait pas
    // exactement), 'pending' : l'agent confirme ou corrige le type depuis
    // l'écran de transaction (déjà existant pour ce statut).
    'status': smsMatch.needsConfirmation ? 'pending' : 'completed',
    'source': 'sms_auto',
    'sms_id': smsId,
    'sms_raw': body,
    'match_confidence': smsMatch.confidence < 100 ? smsMatch.confidence : null,
    'created_at': now.toIso8601String(),
  };
  await TransactionRepository.instance.insert(txData);

  // Met à jour le solde caisse — auto-créée pour cet opérateur si elle
  // n'existait pas encore, dès que le SMS annonce un solde (voir
  // CaisseRepository.updateSoldeAfterTransaction) : inutile d'attendre que
  // l'agent initialise manuellement la caisse pour que le tableau de bord
  // reflète le vrai solde. C'était auparavant fait UNIQUEMENT pour les
  // transactions créées manuellement, jamais pour la détection SMS ni
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

  // 8. Notification selon client connu/inconnu, et selon la confiance du
  // match — un match flou à confirmer le dit explicitement, pour que
  // l'agent sache qu'il doit vérifier/corriger plutôt que juste annuler.
  final String contexte;
  if (smsMatch.needsConfirmation) {
    contexte = '$typeLabel incertain (${smsMatch.confidence}%) - Appuyez pour vérifier';
  } else if (clientExists) {
    contexte = '$typeLabel - $clientName';
  } else {
    contexte = '$typeLabel - Nouveau client. Appuyez pour compléter.';
  }
  await NotificationService().showPendingTransactionNotification(
    transactionId: txId,
    type: transactionType,
    typeLabel: typeLabel,
    amount: amount,
    clientPhone: clientPhone ?? (clientExists ? '' : 'inconnu'),
    operatorName: contexte,
  );

  onTransactionDetected?.call({...txData, 'operator_name': operatorName});
  debugPrint('[SMS] ✅ $typeLabel ${amount.toInt()} FCFA — ${clientPhone ?? "?"} ($operatorName)');

  // Pousse la nouvelle transaction vers le backend sans attendre le
  // prochain tick du timer (D-sync) — no-op immédiat si compte Particulier.
  SyncService.pushIfNeeded();
}
