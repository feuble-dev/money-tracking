import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/transaction_repository.dart';
import '../models/transaction_filter.dart';
import '../models/transaction_model.dart';

export '../models/transaction_filter.dart';

const _uuid = Uuid();

/// Taille d'une page de la liste ; la suivante se charge au défilement.
const kTransactionsPageSize = 100;

/// Une liste paginée : les lignes déjà chargées, s'il en reste, et les
/// totaux calculés en SQL sur TOUT le filtre (pas seulement les lignes
/// chargées — l'ancien total devenait faux au-delà de 500 lignes).
class TransactionPage {
  final List<TransactionModel> items;
  final bool hasMore;
  final int count;
  final double totalIn;
  final double totalOut;

  const TransactionPage({
    required this.items,
    required this.hasMore,
    required this.count,
    required this.totalIn,
    required this.totalOut,
  });

  TransactionPage append(List<TransactionModel> more, {required bool hasMore}) =>
      TransactionPage(
        items: [...items, ...more],
        hasMore: hasMore,
        count: count,
        totalIn: totalIn,
        totalOut: totalOut,
      );
}

/// Provider pour le filtre actif
final transactionFilterProvider =
    StateProvider<TransactionFilter>((ref) => const TransactionFilter());

/// Liste paginée des transactions terminées, selon le filtre actif.
final transactionsProvider =
    StateNotifierProvider<TransactionsNotifier, AsyncValue<TransactionPage>>(
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
    SELECT t.*, o.name as operator_name, tt.label as type_label
    FROM transactions t
    LEFT JOIN operators o ON t.operator_id = o.id
    LEFT JOIN transaction_types tt ON t.transaction_type_id = tt.id
    WHERE t.created_at BETWEEN ? AND ? AND t.status = 'completed'
    ORDER BY t.created_at DESC
  ''', [start, end]);

  return results.map((e) => TransactionModel.fromMap(e)).toList();
});

/// Clause WHERE de la liste pour [filter] (transactions terminées).
(String, List<Object?>) transactionWhere(TransactionFilter filter) {
  final where = StringBuffer("t.status = 'completed'");
  final args = <Object?>[];
  void add(String clause, Object? value) {
    where.write(' AND $clause');
    args.add(value);
  }

  if (filter.operatorId != null) add('t.operator_id = ?', filter.operatorId);
  if (filter.clientId != null) add('t.client_id = ?', filter.clientId);
  if (filter.transactionType != null) add('t.transaction_type = ?', filter.transactionType);
  if (filter.direction != null) add('t.direction = ?', filter.direction);
  if (filter.category == '__uncat__') {
    where.write(" AND (t.category IS NULL OR t.category = '')");
  } else if (filter.category != null) {
    add('t.category = ?', filter.category);
  }
  if (filter.dateFrom != null) add('t.created_at >= ?', filter.dateFrom!.toIso8601String());
  if (filter.dateTo != null) add('t.created_at <= ?', filter.dateTo!.toIso8601String());
  final q = filter.searchQuery?.trim() ?? '';
  if (q.isNotEmpty) {
    // Recherche aussi par référence opérateur (ID de transaction du SMS).
    // « % » et « _ » saisis sont cherchés tels quels (échappés avec « ! »).
    final like = '%${q.replaceAll('!', '!!').replaceAll('%', '!%').replaceAll('_', '!_')}%';
    where.write(" AND (t.client_phone LIKE ? ESCAPE '!' "
        "OR t.client_name LIKE ? ESCAPE '!' "
        "OR t.operator_transaction_id LIKE ? ESCAPE '!')");
    args.addAll([like, like, like]);
  }
  return (where.toString(), args);
}

/// Même règle que `TransactionModel.isEntrant` : `direction` fait foi,
/// repli sur l'ancien code `deposit` si elle manque.
const _isIn =
    "(t.direction = 'in' OR (t.direction IS NULL AND t.transaction_type = 'deposit'))";

/// Notifier de la liste paginée.
class TransactionsNotifier extends StateNotifier<AsyncValue<TransactionPage>> {
  final Ref _ref;

  TransactionsNotifier(this._ref) : super(const AsyncValue.loading()) {
    loadTransactions();
  }

  /// Numéro de la dernière requête lancée : une réponse plus ancienne qui
  /// arrive après (frappe rapide dans la recherche) est ignorée au lieu
  /// d'écraser des résultats plus récents.
  int _loadSeq = 0;
  bool _loadingMore = false;

  Future<List<TransactionModel>> _page(String where, List<Object?> args, int offset) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT t.*, o.name as operator_name, tt.label as type_label
      FROM transactions t
      LEFT JOIN operators o ON t.operator_id = o.id
      LEFT JOIN transaction_types tt ON t.transaction_type_id = tt.id
      WHERE $where
      ORDER BY t.created_at DESC, t.rowid DESC
      LIMIT $kTransactionsPageSize OFFSET $offset
    ''', args);
    return rows.map(TransactionModel.fromMap).toList();
  }

  /// Recharge depuis le début (nouveau filtre, nouvelle transaction…).
  Future<void> loadTransactions() async {
    final seq = ++_loadSeq;
    try {
      final (where, args) = transactionWhere(_ref.read(transactionFilterProvider));
      final db = await DatabaseHelper.instance.database;
      final totals = (await db.rawQuery('''
        SELECT COUNT(*) AS n,
               COALESCE(SUM(CASE WHEN $_isIn THEN t.amount END), 0) AS total_in,
               COALESCE(SUM(CASE WHEN $_isIn THEN 0 ELSE t.amount END), 0) AS total_out
        FROM transactions t WHERE $where
      ''', args)).first;
      final items = await _page(where, args, 0);
      if (seq != _loadSeq || !mounted) return;
      final count = (totals['n'] as num).toInt();
      state = AsyncValue.data(TransactionPage(
        items: items,
        hasMore: items.length < count,
        count: count,
        totalIn: (totals['total_in'] as num).toDouble(),
        totalOut: (totals['total_out'] as num).toDouble(),
      ));
    } catch (e, st) {
      if (seq != _loadSeq || !mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  /// Page suivante, appelée quand la liste arrive en bas.
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || _loadingMore) return;
    _loadingMore = true;
    final seq = _loadSeq;
    try {
      final (where, args) = transactionWhere(_ref.read(transactionFilterProvider));
      final more = await _page(where, args, current.items.length);
      if (seq != _loadSeq || !mounted) return;
      state = AsyncValue.data(current.append(more,
          hasMore: current.items.length + more.length < current.count));
    } finally {
      _loadingMore = false;
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
        SELECT t.*, o.name as operator_name, tt.label as type_label
        FROM transactions t
        LEFT JOIN operators o ON t.operator_id = o.id
        LEFT JOIN transaction_types tt ON t.transaction_type_id = tt.id
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
      SELECT t.*, o.name as operator_name, tt.label as type_label
      FROM transactions t
      LEFT JOIN operators o ON t.operator_id = o.id
      LEFT JOIN transaction_types tt ON t.transaction_type_id = tt.id
      WHERE t.id = ?
    ''', [id]);
    if (results.isEmpty) return null;
    return TransactionModel.fromMap(results.first);
  }
}
