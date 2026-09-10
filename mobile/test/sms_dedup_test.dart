import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/sms/sms_dedup.dart';

/// Vérifie la déduplication SMS atomique (DB v14) : un même SMS livré deux
/// fois (deux BroadcastReceivers, deux isolates) ne doit créer qu'une seule
/// ligne `sms_messages`. Le point de sérialisation est l'index UNIQUE sur
/// `content_hash` + `ConflictAlgorithm.ignore`.
///
/// Base en mémoire (pas de fichier partagé) pour rester isolé des autres
/// tests qui ouvrent `moneytracking.db`.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  const sender = 'OrangeMoney';
  const body =
      'Cher client, vous avez transfere 2,020.00 FCFA au numero 05030304. '
      'ID Trans: PP260828.1729.19305169. Orange Money BF';

  test('smsContentHash est stable et insensible aux espaces de bord', () {
    expect(smsContentHash(sender, body), smsContentHash(sender, body));
    expect(smsContentHash('  $sender ', '  $body  '),
        smsContentHash(sender, body));
    expect(smsContentHash(sender, body) == smsContentHash(sender, '$body x'),
        isFalse);
  });

  test('insert répété du même SMS → une seule ligne (ConflictAlgorithm.ignore)',
      () async {
    final db = await databaseFactory.openDatabase(inMemoryDatabasePath);
    // Même DDL/index que DatabaseHelper (sms_messages + idx_sms_content_hash).
    await db.execute('''
      CREATE TABLE sms_messages (
        id TEXT PRIMARY KEY, sender TEXT, body TEXT NOT NULL,
        received_at TEXT NOT NULL, processed INTEGER DEFAULT 0,
        transaction_id TEXT, pattern_id TEXT, content_hash TEXT, created_at TEXT
      )
    ''');
    await db.execute(
        'CREATE UNIQUE INDEX idx_sms_content_hash ON sms_messages(content_hash)');

    Future<int> insertSms(String id) => db.insert(
          'sms_messages',
          {
            'id': id,
            'sender': sender,
            'body': body,
            'received_at': DateTime.now().toIso8601String(),
            'processed': 0,
            'content_hash': smsContentHash(sender, body),
            'created_at': DateTime.now().toIso8601String(),
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );

    final first = await insertSms('sms-1');
    final second = await insertSms('sms-2');

    expect(first, greaterThan(0));
    expect(second, 0); // rejeté par l'index unique → pas de doublon

    final rows = await db.query('sms_messages');
    expect(rows.length, 1);
    expect(rows.first['id'], 'sms-1');

    await db.close();
  });
}
