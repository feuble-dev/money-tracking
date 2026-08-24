import 'package:sqflite/sqflite.dart';
import 'database_helper.dart';

/// Repository centralisé pour les opérations sur les transactions
/// Gère automatiquement la mise à jour du cache daily_summaries
class TransactionRepository {
  TransactionRepository._();
  static final TransactionRepository instance = TransactionRepository._();

  /// Insère une transaction et met à jour le cache si completed
  Future<void> insert(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('transactions', data);

    if (data['status'] == 'completed') {
      await _refreshCache(db, data['operator_id'] as String,
          DateTime.parse(data['created_at'] as String));
    }
  }

  /// Met à jour une transaction (ex: confirmation pending → completed)
  Future<void> update(Map<String, dynamic> data, String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('transactions', data, where: 'id = ?', whereArgs: [id]);

    // Rafraîchir le cache si le status change vers completed
    if (data['status'] == 'completed' || data.containsKey('status')) {
      final tx = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
      if (tx.isNotEmpty) {
        final row = tx.first;
        if (row['status'] == 'completed') {
          await _refreshCache(db, row['operator_id'] as String,
              DateTime.parse(row['created_at'] as String));
        }
      }
    }
  }

  /// Confirme une transaction pending (avec mise à jour des champs)
  Future<void> confirm(String id, Map<String, dynamic> updates) async {
    final db = await DatabaseHelper.instance.database;
    updates['status'] = 'completed';
    await db.update('transactions', updates, where: 'id = ?', whereArgs: [id]);

    final tx = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (tx.isNotEmpty) {
      await _refreshCache(db, tx.first['operator_id'] as String,
          DateTime.parse(tx.first['created_at'] as String));
    }
  }

  /// Rejette une transaction pending
  Future<void> reject(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('transactions', {'status': 'rejected'},
        where: 'id = ?', whereArgs: [id]);
  }

  /// Annule une transaction confirmée (completed → cancelled)
  Future<void> cancel(String id) async {
    final db = await DatabaseHelper.instance.database;
    final tx = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    await db.update('transactions', {'status': 'cancelled'},
        where: 'id = ?', whereArgs: [id]);
    // Rafraîchir le cache car la transaction sort des completed
    if (tx.isNotEmpty) {
      await _refreshCache(db, tx.first['operator_id'] as String,
          DateTime.parse(tx.first['created_at'] as String));
    }
  }

  /// Revalide une transaction annulée (cancelled/rejected → completed)
  Future<void> revalidate(String id, {Map<String, dynamic>? updates}) async {
    final db = await DatabaseHelper.instance.database;
    final data = {'status': 'completed', ...?updates};
    await db.update('transactions', data, where: 'id = ?', whereArgs: [id]);
    final tx = await db.query('transactions', where: 'id = ?', whereArgs: [id]);
    if (tx.isNotEmpty) {
      await _refreshCache(db, tx.first['operator_id'] as String,
          DateTime.parse(tx.first['created_at'] as String));
    }
  }

  /// Récupère les transactions annulées
  Future<List<Map<String, dynamic>>> getCancelled() async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery('''
      SELECT t.*, o.name as operator_name, tt.label as type_label
      FROM transactions t
      LEFT JOIN operators o ON t.operator_id = o.id
      LEFT JOIN transaction_types tt ON t.transaction_type_id = tt.id
      WHERE t.status IN ('cancelled', 'rejected')
      ORDER BY t.created_at DESC
    ''');
  }

  /// Récupère les résumés quotidiens depuis le cache (ultra rapide)
  Future<List<Map<String, dynamic>>> getDailySummaries({
    required String startDate,
    required String endDate,
    String? operatorId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final opFilter = operatorId != null ? 'AND operator_id = ?' : '';
    final opArgs = operatorId != null ? [operatorId] : <String>[];

    return db.rawQuery('''
      SELECT
        day,
        SUM(deposit_count) as deposit_count,
        SUM(withdrawal_count) as withdrawal_count,
        SUM(deposit_total) as deposit_total,
        SUM(withdrawal_total) as withdrawal_total,
        SUM(unique_clients) as unique_clients,
        MAX(max_deposit) as max_deposit,
        MAX(max_withdrawal) as max_withdrawal
      FROM daily_summaries
      WHERE day BETWEEN ? AND ? $opFilter
      GROUP BY day
      ORDER BY day ASC
    ''', [startDate, endDate, ...opArgs]);
  }

  /// Récupère les stats agrégées pour une période (depuis le cache)
  Future<Map<String, dynamic>> getPeriodStats({
    required String startDate,
    required String endDate,
    String? operatorId,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final opFilter = operatorId != null ? 'AND operator_id = ?' : '';
    final opArgs = operatorId != null ? [operatorId] : <String>[];

    final result = await db.rawQuery('''
      SELECT
        COALESCE(SUM(deposit_count), 0) as deposit_count,
        COALESCE(SUM(withdrawal_count), 0) as withdrawal_count,
        COALESCE(SUM(deposit_total), 0) as deposit_total,
        COALESCE(SUM(withdrawal_total), 0) as withdrawal_total,
        COALESCE(SUM(unique_clients), 0) as unique_clients,
        COALESCE(MAX(max_deposit), 0) as max_deposit,
        COALESCE(MAX(max_withdrawal), 0) as max_withdrawal
      FROM daily_summaries
      WHERE day BETWEEN ? AND ? $opFilter
    ''', [startDate, endDate, ...opArgs]);

    return result.first;
  }

  /// Récupère les stats par opérateur pour le camembert
  Future<List<Map<String, dynamic>>> getOperatorStats({
    required String startDate,
    required String endDate,
  }) async {
    final db = await DatabaseHelper.instance.database;
    return db.rawQuery('''
      SELECT
        o.name, o.id,
        COALESCE(SUM(ds.deposit_total + ds.withdrawal_total), 0) as total,
        COALESCE(SUM(ds.deposit_total), 0) as deposits,
        COALESCE(SUM(ds.withdrawal_total), 0) as withdrawals,
        COALESCE(SUM(ds.deposit_count + ds.withdrawal_count), 0) as tx_count
      FROM daily_summaries ds
      JOIN operators o ON ds.operator_id = o.id
      WHERE ds.day BETWEEN ? AND ?
      GROUP BY o.id
      ORDER BY total DESC
    ''', [startDate, endDate]);
  }

  Future<void> _refreshCache(Database db, String operatorId, DateTime date) async {
    await DatabaseHelper.instance.updateDailySummary(db, operatorId, date);
  }
}
