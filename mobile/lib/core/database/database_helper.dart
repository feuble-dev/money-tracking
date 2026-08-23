import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

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
      version: 9,
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
        catalog_operator_id INTEGER,
        catalog_country_id INTEGER,
        is_custom INTEGER DEFAULT 1,
        synced_at TEXT,
        created_at TEXT
      )
    ''');

    // Catalogue GLOBAL de types de transaction (D3) — une ligne par type,
    // partagée entre tous les opérateurs importés ou créés localement.
    await db.execute('''
      CREATE TABLE transaction_types (
        id TEXT PRIMARY KEY,
        catalog_type_id INTEGER,
        code TEXT NOT NULL UNIQUE,
        label TEXT NOT NULL,
        default_direction TEXT NOT NULL CHECK(default_direction IN ('in','out')),
        is_custom INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');

    // Liaison (opérateur, type) — porte l'USSD/commission propres à la paire.
    await db.execute('''
      CREATE TABLE operator_transaction_types (
        id TEXT PRIMARY KEY,
        operator_id TEXT NOT NULL,
        transaction_type_id TEXT NOT NULL,
        catalog_link_id INTEGER,
        ussd_code TEXT,
        commission_taux REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        FOREIGN KEY (operator_id) REFERENCES operators(id) ON DELETE CASCADE,
        FOREIGN KEY (transaction_type_id) REFERENCES transaction_types(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE sms_patterns (
        id TEXT PRIMARY KEY,
        operator_id TEXT NOT NULL,
        transaction_type TEXT NOT NULL,
        operator_transaction_type_id TEXT,
        catalog_pattern_id INTEGER,
        direction TEXT,
        tagged_zones_json TEXT,
        source TEXT DEFAULT 'custom',
        sender_filter TEXT,
        raw_example TEXT NOT NULL,
        pattern_json TEXT NOT NULL,
        regex_generated TEXT NOT NULL,
        created_at TEXT,
        FOREIGN KEY (operator_id) REFERENCES operators(id) ON DELETE CASCADE,
        FOREIGN KEY (operator_transaction_type_id) REFERENCES operator_transaction_types(id) ON DELETE CASCADE
      )
    ''');

    // Agences (D8) — unité de regroupement/facturation, "tag" sur
    // clients/transactions/caisse (pas des espaces de données isolés).
    await db.execute('''
      CREATE TABLE agences (
        id TEXT PRIMARY KEY,
        backend_agence_id INTEGER,
        nom TEXT NOT NULL,
        is_default INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE agence_operators (
        agence_id TEXT NOT NULL,
        operator_id TEXT NOT NULL,
        PRIMARY KEY (agence_id, operator_id),
        FOREIGN KEY (agence_id) REFERENCES agences(id) ON DELETE CASCADE,
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
        agence_id TEXT,
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
        transaction_type_id TEXT,
        direction TEXT,
        agence_id TEXT,
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
        agence_id TEXT,
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
        agence_id TEXT,
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

    // Cache journalier générique (remplacera daily_summaries à la Phase 5 —
    // créée dès maintenant pour éviter un second bump de version).
    await db.execute('''
      CREATE TABLE daily_summaries_v2 (
        day TEXT NOT NULL,
        agence_id TEXT NOT NULL,
        operator_id TEXT NOT NULL,
        transaction_type_id TEXT NOT NULL,
        direction TEXT NOT NULL,
        tx_count INTEGER DEFAULT 0,
        tx_total REAL DEFAULT 0,
        commission_total REAL DEFAULT 0,
        unique_clients INTEGER DEFAULT 0,
        max_amount REAL DEFAULT 0,
        updated_at TEXT,
        PRIMARY KEY (day, agence_id, operator_id, transaction_type_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE general_notifications (
        id INTEGER PRIMARY KEY,
        titre TEXT NOT NULL,
        message TEXT NOT NULL,
        cible TEXT DEFAULT 'all',
        is_read INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        fetched_at TEXT NOT NULL
      )
    ''');

    // Vue optimisée transactions + opérateur
    await db.execute('''
      CREATE VIEW v_transactions_with_operator AS
      SELECT t.*, o.name as operator_name
      FROM transactions t
      LEFT JOIN operators o ON t.operator_id = o.id
    ''');

    await _createIndexes(db);
    await _seedDefaultTransactionTypes(db);
  }

  /// Types globaux 'deposit'/'withdrawal' toujours présents, même sur une
  /// install neuve — sert de socle avant tout import catalogue (D3).
  Future<void> _seedDefaultTransactionTypes(Database db) async {
    final now = DateTime.now().toIso8601String();
    final existing = await db.query('transaction_types',
        where: 'code IN (?, ?)', whereArgs: ['deposit', 'withdrawal']);
    if (existing.isNotEmpty) return;
    await db.insert('transaction_types', {
      'id': _uuid.v4(),
      'code': 'deposit',
      'label': 'Dépôt',
      'default_direction': 'in',
      'is_custom': 1,
      'created_at': now,
    });
    await db.insert('transaction_types', {
      'id': _uuid.v4(),
      'code': 'withdrawal',
      'label': 'Retrait',
      'default_direction': 'out',
      'is_custom': 1,
      'created_at': now,
    });
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
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_gen_notif_read ON general_notifications(is_read, created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_cancelled ON transactions(status) WHERE status IN (\'cancelled\', \'rejected\')');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_source_status ON transactions(source, status, created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_op_types_operator ON operator_transaction_types(operator_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_sms_patterns_op_type ON sms_patterns(operator_transaction_type_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_agence_status_date ON transactions(agence_id, status, created_at)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_clients_agence ON clients(agence_id)');
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_daily_v2_day_agence ON daily_summaries_v2(day, agence_id)');
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
    if (oldVersion < 8) {
      // Table notifications générales (depuis le backend)
      await db.execute('''
        CREATE TABLE IF NOT EXISTS general_notifications (
          id INTEGER PRIMARY KEY,
          titre TEXT NOT NULL,
          message TEXT NOT NULL,
          cible TEXT DEFAULT 'all',
          is_read INTEGER DEFAULT 0,
          created_at TEXT NOT NULL,
          fetched_at TEXT NOT NULL
        )
      ''');
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_gen_notif_read ON general_notifications(is_read, created_at)');
      // Index pour les transactions annulées (filtré)
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_tx_cancelled ON transactions(status) WHERE status IN (\'cancelled\', \'rejected\')');
      // Index pour source sms_auto (utilisé par notifications)
      await db.execute(
          'CREATE INDEX IF NOT EXISTS idx_tx_source_status ON transactions(source, status, created_at)');
      // Vue optimisée pour les transactions récentes avec opérateur
      await db.execute('DROP VIEW IF EXISTS v_transactions_with_operator');
      await db.execute('''
        CREATE VIEW v_transactions_with_operator AS
        SELECT t.*, o.name as operator_name
        FROM transactions t
        LEFT JOIN operators o ON t.operator_id = o.id
      ''');
    }
    if (oldVersion < 9) {
      await _upgradeToV9(db);
    }
  }

  /// Catalogue d'opérateurs centralisé, types de transaction génériques,
  /// multi-agence (D3/D8). Purement additif : les colonnes/tables existantes
  /// et le comportement de l'app restent inchangés tant que les Phases 5/6
  /// (moteur de matching, runtime multi-agence) ne les consomment pas.
  Future<void> _upgradeToV9(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS transaction_types (
        id TEXT PRIMARY KEY,
        catalog_type_id INTEGER,
        code TEXT NOT NULL UNIQUE,
        label TEXT NOT NULL,
        default_direction TEXT NOT NULL CHECK(default_direction IN ('in','out')),
        is_custom INTEGER DEFAULT 1,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS operator_transaction_types (
        id TEXT PRIMARY KEY,
        operator_id TEXT NOT NULL,
        transaction_type_id TEXT NOT NULL,
        catalog_link_id INTEGER,
        ussd_code TEXT,
        commission_taux REAL DEFAULT 0,
        is_active INTEGER DEFAULT 1,
        created_at TEXT,
        FOREIGN KEY (operator_id) REFERENCES operators(id) ON DELETE CASCADE,
        FOREIGN KEY (transaction_type_id) REFERENCES transaction_types(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS agences (
        id TEXT PRIMARY KEY,
        backend_agence_id INTEGER,
        nom TEXT NOT NULL,
        is_default INTEGER DEFAULT 0,
        created_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS agence_operators (
        agence_id TEXT NOT NULL,
        operator_id TEXT NOT NULL,
        PRIMARY KEY (agence_id, operator_id),
        FOREIGN KEY (agence_id) REFERENCES agences(id) ON DELETE CASCADE,
        FOREIGN KEY (operator_id) REFERENCES operators(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_summaries_v2 (
        day TEXT NOT NULL,
        agence_id TEXT NOT NULL,
        operator_id TEXT NOT NULL,
        transaction_type_id TEXT NOT NULL,
        direction TEXT NOT NULL,
        tx_count INTEGER DEFAULT 0,
        tx_total REAL DEFAULT 0,
        commission_total REAL DEFAULT 0,
        unique_clients INTEGER DEFAULT 0,
        max_amount REAL DEFAULT 0,
        updated_at TEXT,
        PRIMARY KEY (day, agence_id, operator_id, transaction_type_id)
      )
    ''');

    for (final stmt in [
      'ALTER TABLE operators ADD COLUMN catalog_operator_id INTEGER',
      'ALTER TABLE operators ADD COLUMN catalog_country_id INTEGER',
      'ALTER TABLE operators ADD COLUMN is_custom INTEGER DEFAULT 1',
      'ALTER TABLE operators ADD COLUMN synced_at TEXT',
      'ALTER TABLE sms_patterns ADD COLUMN operator_transaction_type_id TEXT',
      'ALTER TABLE sms_patterns ADD COLUMN catalog_pattern_id INTEGER',
      'ALTER TABLE sms_patterns ADD COLUMN direction TEXT',
      'ALTER TABLE sms_patterns ADD COLUMN tagged_zones_json TEXT',
      "ALTER TABLE sms_patterns ADD COLUMN source TEXT DEFAULT 'custom'",
      'ALTER TABLE clients ADD COLUMN agence_id TEXT',
      'ALTER TABLE transactions ADD COLUMN transaction_type_id TEXT',
      'ALTER TABLE transactions ADD COLUMN direction TEXT',
      'ALTER TABLE transactions ADD COLUMN agence_id TEXT',
      'ALTER TABLE caisse ADD COLUMN agence_id TEXT',
      'ALTER TABLE caisse_operations ADD COLUMN agence_id TEXT',
    ]) {
      try {
        await db.execute(stmt);
      } catch (_) {}
    }

    await _seedDefaultTransactionTypes(db);

    // Backfill operator_transaction_types depuis les anciennes colonnes
    // taux_commission_*/ussd_*_template (2 lignes par opérateur existant).
    final depositType = (await db.query('transaction_types',
            where: 'code = ?', whereArgs: ['deposit']))
        .first;
    final withdrawalType = (await db.query('transaction_types',
            where: 'code = ?', whereArgs: ['withdrawal']))
        .first;
    final operators = await db.query('operators');
    for (final op in operators) {
      final operatorId = op['id'] as String;
      final existingLinks = await db.query('operator_transaction_types',
          where: 'operator_id = ?', whereArgs: [operatorId]);
      if (existingLinks.isNotEmpty) continue;
      final now = DateTime.now().toIso8601String();
      await db.insert('operator_transaction_types', {
        'id': _uuid.v4(),
        'operator_id': operatorId,
        'transaction_type_id': depositType['id'],
        'ussd_code': op['ussd_deposit_template'],
        'commission_taux': op['taux_commission_depot'] ?? 0,
        'is_active': 1,
        'created_at': now,
      });
      await db.insert('operator_transaction_types', {
        'id': _uuid.v4(),
        'operator_id': operatorId,
        'transaction_type_id': withdrawalType['id'],
        'ussd_code': op['ussd_withdraw_template'],
        'commission_taux': op['taux_commission_retrait'] ?? 0,
        'is_active': 1,
        'created_at': now,
      });
    }

    // Agence par défaut — rattache tout l'existant (D8 : tag, pas d'espace isolé).
    final existingAgences = await db.query('agences');
    String defaultAgenceId;
    if (existingAgences.isEmpty) {
      defaultAgenceId = _uuid.v4();
      await db.insert('agences', {
        'id': defaultAgenceId,
        'nom': 'Agence principale',
        'is_default': 1,
        'created_at': DateTime.now().toIso8601String(),
      });
      for (final op in operators) {
        await db.insert(
          'agence_operators',
          {'agence_id': defaultAgenceId, 'operator_id': op['id']},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    } else {
      defaultAgenceId = existingAgences.first['id'] as String;
    }

    await db.update('clients', {'agence_id': defaultAgenceId},
        where: 'agence_id IS NULL');
    await db.update('transactions', {'agence_id': defaultAgenceId},
        where: 'agence_id IS NULL');
    await db.update('caisse', {'agence_id': defaultAgenceId},
        where: 'agence_id IS NULL');
    await db.update('caisse_operations', {'agence_id': defaultAgenceId},
        where: 'agence_id IS NULL');

    // Backfill transaction_type_id/direction (transactions) et
    // direction/operator_transaction_type_id/source (sms_patterns).
    await db.rawUpdate('''
      UPDATE transactions
      SET transaction_type_id = (SELECT id FROM transaction_types WHERE code = transactions.transaction_type),
          direction = (SELECT default_direction FROM transaction_types WHERE code = transactions.transaction_type)
      WHERE transaction_type_id IS NULL
    ''');
    await db.rawUpdate('''
      UPDATE sms_patterns
      SET direction = (SELECT default_direction FROM transaction_types WHERE code = sms_patterns.transaction_type),
          source = COALESCE(source, 'custom')
      WHERE direction IS NULL
    ''');
    await db.rawUpdate('''
      UPDATE sms_patterns
      SET operator_transaction_type_id = (
        SELECT ott.id FROM operator_transaction_types ott
        JOIN transaction_types tt ON tt.id = ott.transaction_type_id
        WHERE ott.operator_id = sms_patterns.operator_id AND tt.code = sms_patterns.transaction_type
      )
      WHERE operator_transaction_type_id IS NULL
    ''');

    await _createIndexes(db);
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
