import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../models/operator_model.dart';
import '../models/sms_pattern_model.dart';

const _uuid = Uuid();

/// Provider pour la liste des opérateurs
final operatorsProvider =
    StateNotifierProvider<OperatorsNotifier, AsyncValue<List<OperatorModel>>>(
        (ref) {
  return OperatorsNotifier();
});

/// Provider pour les patterns SMS d'un opérateur
final smsPatternsProvider = FutureProvider.family<List<SmsPatternModel>, String>(
    (ref, operatorId) async {
  final db = await DatabaseHelper.instance.database;
  final results = await db.query(
    'sms_patterns',
    where: 'operator_id = ?',
    whereArgs: [operatorId],
    orderBy: 'created_at DESC',
  );
  return results.map((e) => SmsPatternModel.fromMap(e)).toList();
});

/// Notifier pour les opérations CRUD sur les opérateurs
class OperatorsNotifier
    extends StateNotifier<AsyncValue<List<OperatorModel>>> {
  OperatorsNotifier() : super(const AsyncValue.loading()) {
    loadOperators();
  }

  Future<void> loadOperators() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query('operators', orderBy: 'name ASC');
      final operators =
          results.map((e) => OperatorModel.fromMap(e)).toList();
      state = AsyncValue.data(operators);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addOperator(OperatorModel operator_) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('operators', operator_.toMap());
    await loadOperators();
  }

  Future<void> updateOperator(OperatorModel operator_) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'operators',
      operator_.toMap(),
      where: 'id = ?',
      whereArgs: [operator_.id],
    );
    await loadOperators();
  }

  Future<void> toggleActive(String id, bool isActive) async {
    final db = await DatabaseHelper.instance.database;
    await db.update(
      'operators',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
    await loadOperators();
  }

  Future<void> deleteOperator(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('operators', where: 'id = ?', whereArgs: [id]);
    await loadOperators();
  }
}

/// Fonctions helper pour les patterns SMS
class SmsPatternRepository {
  static Future<void> savePattern(SmsPatternModel pattern) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('sms_patterns', pattern.toMap());
  }

  static Future<void> deletePattern(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('sms_patterns', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<SmsPatternModel>> getPatternsForOperator(
      String operatorId) async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query(
      'sms_patterns',
      where: 'operator_id = ?',
      whereArgs: [operatorId],
    );
    return results.map((e) => SmsPatternModel.fromMap(e)).toList();
  }

  static String generateId() => _uuid.v4();
}
