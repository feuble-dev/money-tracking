import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/database/database_helper.dart';
import 'package:moneytracking/core/sms/sms_pattern_builder.dart';
import 'package:moneytracking/core/sms/sms_processing_pipeline.dart';

/// Un SMS reçu pendant une licence inactive n'est plus perdu : il reste en
/// attente puis devient une transaction dès que la licence est renouvelée.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.debugDatabaseName = 'moneytracking_replay_test.db';

  const sender = 'OrangeMoney';
  const body = 'Vous avez recu 5000 FCFA du 70112233. '
      'Nouveau solde: 12000 FCFA. ID: AB123';

  Future<void> licence(String dateFin) async {
    FlutterSecureStorage.setMockInitialValues({
      'mt_licence': jsonEncode({'statut': 'active', 'date_fin': dateFin}),
    });
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({'account_type': 'agence'});
    await DatabaseHelper.instance.close();
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory
        .deleteDatabase(join(dir, DatabaseHelper.debugDatabaseName));
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    await db.insert('operators', {
      'id': 'op1', 'name': 'Orange Money', 'sms_sender': sender,
      'is_active': 1, 'created_at': now,
    });
    await db.insert('transaction_types', {
      'id': 'tt-recu', 'code': 'transfert_recu', 'label': 'Transfert reçu',
      'default_direction': 'in', 'created_at': now,
    });
    await db.insert('operator_transaction_types', {
      'id': 'ott1', 'operator_id': 'op1', 'transaction_type_id': 'tt-recu',
      'is_active': 1, 'created_at': now,
    });
    TaggedZone zone(String value, String field) {
      final start = body.indexOf(value);
      return TaggedZone(
          start: start, end: start + value.length, fieldName: field, value: value);
    }

    final zones = [
      zone('5000', 'montant'),
      zone('70112233', 'numero_client'),
      zone('12000', 'solde'),
      zone('AB123', 'operator_transaction_id'),
    ];
    await db.insert('sms_patterns', {
      'id': 'p1', 'operator_id': 'op1', 'transaction_type': 'transfert_recu',
      'operator_transaction_type_id': 'ott1', 'direction': 'in',
      'tagged_zones_json': SmsPatternBuilder.zonesToJson(zones),
      'raw_example': body, 'pattern_json': '{}',
      'regex_generated': SmsPatternBuilder.buildRegex(body, zones),
      'created_at': now,
    });
  });

  Future<List<Map<String, Object?>>> txs() async =>
      (await DatabaseHelper.instance.database).query('transactions');

  test('licence inactive : SMS mis en attente, rejoué au renouvellement',
      () async {
    await licence('2020-01-01'); // expirée
    await processIncomingSms(sender, body);

    final db = await DatabaseHelper.instance.database;
    final sms = await db.query('sms_messages');
    expect(sms.single['processed'], SmsStatus.pending);
    expect(await txs(), isEmpty);

    // Toujours expirée : le rejeu ne fait rien.
    expect(await replayPendingSms(), 0);

    await licence('2099-01-01'); // renouvelée
    expect(await replayPendingSms(), 1);
    final created = await txs();
    expect(created.single['amount'], 5000);
    expect(created.single['operator_transaction_id'], 'AB123');
    expect((await db.query('sms_messages')).single['processed'],
        SmsStatus.transaction);

    // Idempotent : rien à rejouer la seconde fois.
    expect(await replayPendingSms(), 0);
    expect((await txs()).length, 1);
  });

  test('SMS qui n\'est pas une transaction → ignoré, jamais rejoué', () async {
    await licence('2099-01-01');
    await processIncomingSms(sender, 'Profitez de notre offre bonus !');
    final db = await DatabaseHelper.instance.database;
    expect((await db.query('sms_messages')).single['processed'],
        SmsStatus.ignored);
    expect(await replayPendingSms(), 0);
  });

  test('Particulier : jamais bloqué par la licence', () async {
    SharedPreferences.setMockInitialValues({'account_type': 'particulier'});
    FlutterSecureStorage.setMockInitialValues({});
    await processIncomingSms(sender, body);
    expect((await txs()).length, 1);
  });
}
