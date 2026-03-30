import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/transaction_repository.dart';
import '../models/transaction_filter.dart';
import '../models/transaction_model.dart';

export '../models/transaction_filter.dart';

const _uuid = Uuid();

/// Provider pour le filtre actif
final transactionFilterProvider =
    StateProvider<TransactionFilter>((ref) => const TransactionFilter());

/// Provider pour la liste des transactions filtrées (uniquement completed)
final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, AsyncValue<List<TransactionModel>>>(
        (ref) {
  return TransactionsNotifier(ref);
});

/// Provider pour les transactions en attente de confirmation
final pendingTransactionsProvider =
    StateNotifierProvider<PendingTransactionsNotifier, AsyncValue<List<TransactionModel>>>(
        (ref) {
  return PendingTransactionsNotifier();
});

/// Provider pour le nombre de transactions en attente (pour le badge)
final pendingCountProvider = Provider<int>((ref) {
  final pending = ref.watch(pendingTransactionsProvider);
  return pending.valueOrNull?.length ?? 0;
});

/// Provider pour les transactions du jour — optimisé avec le cache
final todayTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day).toIso8601String();
  final end = DateTime(today.year, today.month, today.day, 23, 59, 59)
      .toIso8601String();

  final results = await db.rawQuery('''
    SELECT t.*, o.name as operator_name
    FROM transactions t
    LEFT JOIN operators o ON t.operator_id = o.id
    WHERE t.created_at BETWEEN ? AND ? AND t.status = 'completed'
    ORDER BY t.created_at DESC
  ''', [start, end]);

  return results.map((e) => TransactionModel.fromMap(e)).toList();
});

/// Notifier pour les transactions confirmées
class TransactionsNotifier
    extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  final Ref _ref;

  TransactionsNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadTransactions();
  }

  Future<void> loadTransactions() async {
    try {
      final filter = _ref.read(transactionFilterProvider);
      final db = await DatabaseHelper.instance.database;

      // Construction de la requête optimisée
      final where = StringBuffer('t.status = ?');
      final whereArgs = <dynamic>['completed'];

      if (filter.operatorId != null) {
        where.write(' AND t.operator_id = ?');
        whereArgs.add(filter.operatorId);
      }
      if (filter.clientId != null) {
        where.write(' AND t.client_id = ?');
        whereArgs.add(filter.clientId);
      }
      if (filter.transactionType != null) {
        where.write(' AND t.transaction_type = ?');
        whereArgs.add(filter.transactionType);
      }
      if (filter.dateFrom != null) {
        where.write(' AND t.created_at >= ?');
        whereArgs.add(filter.dateFrom!.toIso8601String());
      }
      if (filter.dateTo != null) {
        where.write(' AND t.created_at <= ?');
        whereArgs.add(filter.dateTo!.toIso8601String());
      }
      if (filter.searchQuery != null && filter.searchQuery!.isNotEmpty) {
        where.write(' AND (t.client_phone LIKE ? OR t.client_name LIKE ?)');
        whereArgs.add('%${filter.searchQuery}%');
        whereArgs.add('%${filter.searchQuery}%');
      }

      final results = await db.rawQuery('''
        SELECT t.*, o.name as operator_name
        FROM transactions t
        LEFT JOIN operators o ON t.operator_id = o.id
        WHERE $where
        ORDER BY t.created_at DESC
        LIMIT 500
      ''', whereArgs);

      state = AsyncValue.data(
          results.map((e) => TransactionModel.fromMap(e)).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    await TransactionRepository.instance.insert(transaction.toMap());
    await loadTransactions();
  }

  static String generateId() => _uuid.v4();
}

/// Notifier pour les transactions en attente de confirmation
class PendingTransactionsNotifier
    extends StateNotifier<AsyncValue<List<TransactionModel>>> {
  PendingTransactionsNotifier() : super(const AsyncValue.loading()) {
    loadPending();
  }

  Future<void> loadPending() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.rawQuery('''
        SELECT t.*, o.name as operator_name
        FROM transactions t
        LEFT JOIN operators o ON t.operator_id = o.id
        WHERE t.status = 'pending'
        ORDER BY t.created_at DESC
      ''');
      state = AsyncValue.data(
          results.map((e) => TransactionModel.fromMap(e)).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> confirmTransaction(TransactionModel transaction) async {
    final updated = transaction.copyWith(status: 'completed');
    await TransactionRepository.instance.confirm(
      transaction.id,
      updated.toMap(),
    );
    await loadPending();
  }

  Future<void> rejectTransaction(String transactionId) async {
    await TransactionRepository.instance.reject(transactionId);
    await loadPending();
  }

  Future<TransactionModel?> getById(String id) async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.rawQuery('''
      SELECT t.*, o.name as operator_name
      FROM transactions t
      LEFT JOIN operators o ON t.operator_id = o.id
      WHERE t.id = ?
    ''', [id]);
    if (results.isEmpty) return null;
    return TransactionModel.fromMap(results.first);
  }
}
