import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/database/database_helper.dart';

/// Vérifie que la migration v8 -> v9 (catalogue d'opérateurs, types de
/// transaction génériques, multi-agence) préserve les données existantes
/// et les rattache correctement à l'agence par défaut, sans toucher au
/// comportement des colonnes historiques.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test('v8 -> v9 backfills agence, types, direction and links correctly',
      () async {
    final dbDir = await databaseFactory.getDatabasesPath();
    final path = join(dbDir, 'moneytracking.db');
    await databaseFactory.deleteDatabase(path);

    // Recrée le schéma legacy v8 tel qu'il existait en prod avant cette
    // migration, avec des données représentatives d'un agent déjà actif.
    final legacy = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 8,
        onCreate: (db, v) async {
          await db.execute('''
            CREATE TABLE operators (
              id TEXT PRIMARY KEY, name TEXT NOT NULL, logo_path TEXT,
              account_number TEXT, agent_number TEXT, sms_sender TEXT,
              ussd_deposit_template TEXT, ussd_withdraw_template TEXT,
              is_active INTEGER DEFAULT 1,
              taux_commission_depot REAL DEFAULT 0,
              taux_commission_retrait REAL DEFAULT 0,
              created_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE sms_patterns (
              id TEXT PRIMARY KEY, operator_id TEXT NOT NULL,
              transaction_type TEXT NOT NULL, sender_filter TEXT,
              raw_example TEXT NOT NULL, pattern_json TEXT NOT NULL,
              regex_generated TEXT NOT NULL, created_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE clients (
              id TEXT PRIMARY KEY, first_name TEXT NOT NULL,
              last_name TEXT NOT NULL, phone_number TEXT UNIQUE NOT NULL,
              cnib_number TEXT, birth_date TEXT, operator_id TEXT,
              created_at TEXT, updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE transactions (
              id TEXT PRIMARY KEY, operator_id TEXT NOT NULL, client_id TEXT,
              transaction_type TEXT NOT NULL, amount REAL NOT NULL,
              commission REAL DEFAULT 0, client_phone TEXT NOT NULL,
              client_name TEXT, client_cnib TEXT, client_birth_date TEXT,
              operator_transaction_id TEXT, operator_reference TEXT,
              status TEXT DEFAULT 'completed', source TEXT DEFAULT 'manual',
              sms_id TEXT, sms_raw TEXT, created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE sms_messages (
              id TEXT PRIMARY KEY, sender TEXT, body TEXT NOT NULL,
              received_at TEXT NOT NULL, processed INTEGER DEFAULT 0,
              transaction_id TEXT, pattern_id TEXT, created_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE caisse (
              id TEXT PRIMARY KEY, operator_id TEXT,
              solde_initial REAL DEFAULT 0, solde_actuel REAL DEFAULT 0,
              seuil_alerte REAL DEFAULT 0, updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE caisse_operations (
              id TEXT PRIMARY KEY, operator_id TEXT, type TEXT NOT NULL,
              montant REAL NOT NULL, note TEXT, created_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE daily_summaries (
              day TEXT NOT NULL, operator_id TEXT NOT NULL,
              deposit_count INTEGER DEFAULT 0, withdrawal_count INTEGER DEFAULT 0,
              deposit_total REAL DEFAULT 0, withdrawal_total REAL DEFAULT 0,
              commission_total REAL DEFAULT 0, unique_clients INTEGER DEFAULT 0,
              max_deposit REAL DEFAULT 0, max_withdrawal REAL DEFAULT 0,
              updated_at TEXT, PRIMARY KEY (day, operator_id)
            )
          ''');
          await db.execute('''
            CREATE TABLE general_notifications (
              id INTEGER PRIMARY KEY, titre TEXT NOT NULL, message TEXT NOT NULL,
              cible TEXT DEFAULT 'all', is_read INTEGER DEFAULT 0,
              created_at TEXT NOT NULL, fetched_at TEXT NOT NULL
            )
          ''');

          final now = DateTime.now().toIso8601String();
          await db.insert('operators', {
            'id': 'op1',
            'name': 'Orange Money',
            'sms_sender': 'OrangeMoney',
            'ussd_deposit_template': '*144*1#',
            'ussd_withdraw_template': '*144*2#',
            'is_active': 1,
            'taux_commission_depot': 1.5,
            'taux_commission_retrait': 0.8,
            'created_at': now,
          });
          await db.insert('clients', {
            'id': 'cl1',
            'first_name': 'Awa',
            'last_name': 'Traore',
            'phone_number': '70123456',
            'created_at': now,
            'updated_at': now,
          });
          await db.insert('transactions', {
            'id': 'tx1',
            'operator_id': 'op1',
            'client_id': 'cl1',
            'transaction_type': 'deposit',
            'amount': 5000,
            'commission': 75,
            'client_phone': '70123456',
            'status': 'completed',
            'source': 'manual',
            'created_at': now,
          });
          await db.insert('transactions', {
            'id': 'tx2',
            'operator_id': 'op1',
            'client_id': 'cl1',
            'transaction_type': 'withdrawal',
            'amount': 3000,
            'commission': 24,
            'client_phone': '70123456',
            'status': 'completed',
            'source': 'sms_auto',
            'created_at': now,
          });
          await db.insert('sms_patterns', {
            'id': 'pat1',
            'operator_id': 'op1',
            'transaction_type': 'deposit',
            'raw_example': 'Depot de 5000 FCFA recu de 70123456.',
            'pattern_json': '{}',
            'regex_generated': 'auto_detect',
            'created_at': now,
          });
        },
      ),
    );
    await legacy.close();

    // Ouvre via le vrai DatabaseHelper (version 9) — déclenche _onUpgrade.
    final db = await DatabaseHelper.instance.database;

    final agences = await db.query('agences');
    expect(agences.length, 1);
    expect(agences.first['nom'], 'Agence principale');
    expect(agences.first['is_default'], 1);
    final defaultAgenceId = agences.first['id'] as String;

    final types = await db.query('transaction_types');
    expect(types.length, 2);
    final depositType = types.firstWhere((t) => t['code'] == 'deposit');
    final withdrawalType = types.firstWhere((t) => t['code'] == 'withdrawal');
    expect(depositType['default_direction'], 'in');
    expect(withdrawalType['default_direction'], 'out');

    final links = await db.query('operator_transaction_types',
        where: 'operator_id = ?', whereArgs: ['op1']);
    expect(links.length, 2);
    final depositLink =
        links.firstWhere((l) => l['transaction_type_id'] == depositType['id']);
    expect(depositLink['ussd_code'], '*144*1#');
    expect(depositLink['commission_taux'], 1.5);
    final withdrawalLink = links
        .firstWhere((l) => l['transaction_type_id'] == withdrawalType['id']);
    expect(withdrawalLink['commission_taux'], 0.8);

    final agenceOps = await db.query('agence_operators',
        where: 'agence_id = ?', whereArgs: [defaultAgenceId]);
    expect(agenceOps.length, 1);
    expect(agenceOps.first['operator_id'], 'op1');

    final tx1 =
        (await db.query('transactions', where: 'id = ?', whereArgs: ['tx1']))
            .first;
    expect(tx1['agence_id'], defaultAgenceId);
    expect(tx1['transaction_type_id'], depositType['id']);
    expect(tx1['direction'], 'in');

    final tx2 =
        (await db.query('transactions', where: 'id = ?', whereArgs: ['tx2']))
            .first;
    expect(tx2['direction'], 'out');
    expect(tx2['transaction_type_id'], withdrawalType['id']);

    final client =
        (await db.query('clients', where: 'id = ?', whereArgs: ['cl1']))
            .first;
    expect(client['agence_id'], defaultAgenceId);

    final pattern = (await db
            .query('sms_patterns', where: 'id = ?', whereArgs: ['pat1']))
        .first;
    expect(pattern['direction'], 'in');
    expect(pattern['source'], 'custom');
    expect(pattern['operator_transaction_type_id'], depositLink['id']);

    await DatabaseHelper.instance.close();
  });
}
