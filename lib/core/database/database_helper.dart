import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Helper centralisé pour la base de données SQLite
/// Optimisé avec WAL mode et accès singleton
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'moneytracking.db');

    return await openDatabase(
      path,
      version: 7,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        // WAL mode — doit passer par rawQuery car retourne un résultat
        await db.rawQuery('PRAGMA journal_mode = WAL');
        await db.rawQuery('PRAGMA synchronous = NORMAL');
        await db.rawQuery('PRAGMA cache_size = -4000');
        await db.rawQuery('PRAGMA temp_store = MEMORY');
      },
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE operators (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        logo_path TEXT,
        account_number TEXT,
        agent_number TEXT,
        sms_sender TEXT,
        ussd_deposit_template TEXT,
        ussd_withdraw_template TEXT,
        is_active INTEGER DEFAULT 1,
        taux_commission_depot REAL DEFAULT 0,
        taux_commission_retrait REAL DEFAULT 0,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE sms_patterns (
        id TEXT PRIMARY KEY,
        operator_id TEXT NOT NULL,
        transaction_type TEXT NOT NULL,
        sender_filter TEXT,
        raw_example TEXT NOT NULL,
        pattern_json TEXT NOT NULL,
        regex_generated TEXT NOT NULL,
        created_at TEXT,
        FOREIGN KEY (operator_id) REFERENCES operators(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE clients (
        id TEXT PRIMARY KEY,
        first_name TEXT NOT NULL,
        last_name TEXT NOT NULL,
        phone_number TEXT UNIQUE NOT NULL,
        cnib_number TEXT,
        birth_date TEXT,
        operator_id TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id TEXT PRIMARY KEY,
        operator_id TEXT NOT NULL,
        client_id TEXT,
        transaction_type TEXT NOT NULL,
        amount REAL NOT NULL,
        commission REAL DEFAULT 0,
        client_phone TEXT NOT NULL,
        client_name TEXT,
        client_cnib TEXT,
        client_birth_date TEXT,
        operator_transaction_id TEXT,
        operator_reference TEXT,
        status TEXT DEFAULT 'completed',
        source TEXT DEFAULT 'manual',
        sms_id TEXT,
        sms_raw TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (operator_id) REFERENCES operators(id) ON DELETE CASCADE,
        FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE SET NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE sms_messages (
        id TEXT PRIMARY KEY,
        sender TEXT,
        body TEXT NOT NULL,
        received_at TEXT NOT NULL,
        processed INTEGER DEFAULT 0,
        transaction_id TEXT,
        pattern_id TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE caisse (
        id TEXT PRIMARY KEY,
        operator_id TEXT,
        solde_initial REAL DEFAULT 0,
        solde_actuel REAL DEFAULT 0,
        seuil_alerte REAL DEFAULT 0,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE caisse_operations (
        id TEXT PRIMARY KEY,
        operator_id TEXT,
        type TEXT NOT NULL,
        montant REAL NOT NULL,
        note TEXT,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_summaries (
        day TEXT NOT NULL,
        operator_id TEXT NOT NULL,
        deposit_count INTEGER DEFAULT 0,
        withdrawal_count INTEGER DEFAULT 0,
        deposit_total REAL DEFAULT 0,
        withdrawal_total REAL DEFAULT 0,
        commission_total REAL DEFAULT 0,
        unique_clients INTEGER DEFAULT 0,
        max_deposit REAL DEFAULT 0,
        max_withdrawal REAL DEFAULT 0,
        updated_at TEXT,
        PRIMARY KEY (day, operator_id),
        FOREIGN KEY (operator_id) REFERENCES operators(id) ON DELETE CASCADE
      )
    ''');

    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_clients_phone ON clients(phone_number)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sms_patterns_operator ON sms_patterns(operator_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_status_date ON transactions(status, created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_status_op_date ON transactions(status, operator_id, created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_status_type_date ON transactions(status, transaction_type, created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_client_date ON transactions(client_id, created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_phone_op_amount ON transactions(client_phone, operator_id, amount, source, created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_pending ON transactions(status) WHERE status = \'pending\'');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_daily_summaries_day ON daily_summaries(day)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sms_messages_processed ON sms_messages(processed, received_at)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE transactions ADD COLUMN client_cnib TEXT');
      await db.execute('ALTER TABLE transactions ADD COLUMN client_birth_date TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_summaries (
          day TEXT NOT NULL, operator_id TEXT NOT NULL,
          deposit_count INTEGER DEFAULT 0, withdrawal_count INTEGER DEFAULT 0,
          deposit_total REAL DEFAULT 0, withdrawal_total REAL DEFAULT 0,
          unique_clients INTEGER DEFAULT 0, max_deposit REAL DEFAULT 0,
          max_withdrawal REAL DEFAULT 0, updated_at TEXT,
          PRIMARY KEY (day, operator_id)
        )
      ''');
      await db.execute('DROP INDEX IF EXISTS idx_transactions_operator');
      await db.execute('DROP INDEX IF EXISTS idx_transactions_client');
      await db.execute('DROP INDEX IF EXISTS idx_transactions_date');
      await db.execute('DROP INDEX IF EXISTS idx_transactions_type');
      await db.execute('DROP INDEX IF EXISTS idx_transactions_status');
      await _createIndexes(db);
      await refreshAllSummaries(db);
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE operators ADD COLUMN taux_commission_depot REAL DEFAULT 0');
      await db.execute('ALTER TABLE operators ADD COLUMN taux_commission_retrait REAL DEFAULT 0');
      await db.execute('ALTER TABLE transactions ADD COLUMN commission REAL DEFAULT 0');
      try {
        await db.execute('ALTER TABLE daily_summaries ADD COLUMN commission_total REAL DEFAULT 0');
      } catch (_) {}

      await db.execute('''
        CREATE TABLE IF NOT EXISTS sms_messages (
          id TEXT PRIMARY KEY, sender TEXT, body TEXT NOT NULL,
          received_at TEXT NOT NULL, processed INTEGER DEFAULT 0,
          transaction_id TEXT, pattern_id TEXT, created_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS caisse (
          id TEXT PRIMARY KEY, operator_id TEXT,
          solde_initial REAL DEFAULT 0, solde_actuel REAL DEFAULT 0,
          seuil_alerte REAL DEFAULT 0, updated_at TEXT
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS caisse_operations (
          id TEXT PRIMARY KEY, operator_id TEXT, type TEXT NOT NULL,
          montant REAL NOT NULL, note TEXT, created_at TEXT
        )
      ''');
      await _createIndexes(db);
    }
    if (oldVersion < 5) {
      try {
        await db.execute('ALTER TABLE operators ADD COLUMN sms_sender TEXT');
      } catch (_) {}
    }
    if (oldVersion < 6) {
      try {
        await db.execute('ALTER TABLE clients ADD COLUMN operator_id TEXT');
      } catch (_) {}
    }
    if (oldVersion < 7) {
      try {
        await db.execute('ALTER TABLE transactions ADD COLUMN sms_id TEXT');
      } catch (_) {}
    }
  }

  Future<void> updateDailySummary(Database db, String operatorId, DateTime date) async {
    final day = _dateToKey(date);
    final dayStart = '${day}T00:00:00.000';
    final dayEnd = '${day}T23:59:59.999';

    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN transaction_type='deposit' THEN 1 ELSE 0 END), 0) as dep_count,
        COALESCE(SUM(CASE WHEN transaction_type='withdrawal' THEN 1 ELSE 0 END), 0) as wit_count,
        COALESCE(SUM(CASE WHEN transaction_type='deposit' THEN amount ELSE 0 END), 0) as dep_total,
        COALESCE(SUM(CASE WHEN transaction_type='withdrawal' THEN amount ELSE 0 END), 0) as wit_total,
        COALESCE(SUM(commission), 0) as comm_total,
        COUNT(DISTINCT client_phone) as clients,
        COALESCE(MAX(CASE WHEN transaction_type='deposit' THEN amount END), 0) as max_dep,
        COALESCE(MAX(CASE WHEN transaction_type='withdrawal' THEN amount END), 0) as max_wit
      FROM transactions
      WHERE status = 'completed' AND operator_id = ? AND created_at BETWEEN ? AND ?
    ''', [operatorId, dayStart, dayEnd]);

    final r = result.first;
    await db.insert('daily_summaries', {
      'day': day, 'operator_id': operatorId,
      'deposit_count': r['dep_count'], 'withdrawal_count': r['wit_count'],
      'deposit_total': r['dep_total'], 'withdrawal_total': r['wit_total'],
      'commission_total': r['comm_total'], 'unique_clients': r['clients'],
      'max_deposit': r['max_dep'], 'max_withdrawal': r['max_wit'],
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> refreshAllSummaries(Database db) async {
    await db.delete('daily_summaries');
    final days = await db.rawQuery('''
      SELECT DISTINCT DATE(created_at) as day, operator_id
      FROM transactions WHERE status = 'completed'
    ''');
    for (final row in days) {
      await updateDailySummary(db, row['operator_id'] as String,
          DateTime.parse(row['day'] as String));
    }
  }

  String _dateToKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> close() async {
    final db = await database;
    db.close();
    _database = null;
  }
}
