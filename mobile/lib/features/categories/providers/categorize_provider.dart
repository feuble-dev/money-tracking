import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../transactions/models/transaction_model.dart';

/// File des dépenses non catégorisées (statut completed, direction 'out',
/// `category` vide), plus récentes d'abord. Alimente l'écran de
/// catégorisation rapide et le bandeau « à catégoriser ».
final uncategorizedTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.rawQuery('''
    SELECT t.*, o.name as operator_name, tt.label as type_label
    FROM transactions t
    LEFT JOIN operators o ON t.operator_id = o.id
    LEFT JOIN transaction_types tt ON t.transaction_type_id = tt.id
    WHERE t.status = 'completed'
      AND t.direction = 'out'
      AND (t.category IS NULL OR t.category = '')
    ORDER BY t.created_at DESC
    LIMIT 200
  ''');
  return rows.map(TransactionModel.fromMap).toList();
});

/// Une transaction précise (pour l'entrée « catégoriser celle-ci » depuis
/// une notification ou le détail d'une transaction).
final singleTransactionProvider =
    FutureProvider.family<TransactionModel?, String>((ref, id) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.rawQuery('''
    SELECT t.*, o.name as operator_name, tt.label as type_label
    FROM transactions t
    LEFT JOIN operators o ON t.operator_id = o.id
    LEFT JOIN transaction_types tt ON t.transaction_type_id = tt.id
    WHERE t.id = ?
  ''', [id]);
  return rows.isEmpty ? null : TransactionModel.fromMap(rows.first);
});
