import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import 'expense_category.dart';

const _uuid = Uuid();

/// Accès au catalogue local de catégories (motifs), aux règles
/// d'auto-catégorisation et aux budgets. Classe statique sans dépendance
/// Riverpod — comme [CaisseRepository], elle doit être appelable depuis
/// l'isolate headless du pipeline SMS (`sms_processing_pipeline.dart`).
class CategoryRepository {
  CategoryRepository._();

  // ---------------------------------------------------------------------------
  // Catalogue
  // ---------------------------------------------------------------------------

  static Future<List<ExpenseCategory>> getAll({
    bool activeOnly = true,
    String? direction, // 'in' | 'out' — filtre optionnel
  }) async {
    final db = await DatabaseHelper.instance.database;
    final where = <String>[];
    final args = <Object?>[];
    if (activeOnly) where.add('is_active = 1');
    if (direction != null) {
      where.add("(direction = ? OR direction = 'both')");
      args.add(direction);
    }
    final rows = await db.query(
      'expense_categories',
      where: where.isEmpty ? null : where.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'sort_order ASC, label ASC',
    );
    return rows.map(ExpenseCategory.fromMap).toList();
  }

  /// Map `code -> ExpenseCategory` (toutes, même inactives) pour résoudre le
  /// libellé/emoji/couleur d'une transaction déjà catégorisée sans requête
  /// par ligne.
  static Future<Map<String, ExpenseCategory>> byCode() async {
    final all = await getAll(activeOnly: false);
    return {for (final c in all) c.code: c};
  }

  static Future<ExpenseCategory?> getByCode(String code) async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('expense_categories',
        where: 'code = ?', whereArgs: [code], limit: 1);
    return rows.isEmpty ? null : ExpenseCategory.fromMap(rows.first);
  }

  static Future<ExpenseCategory> createCustom({
    required String label,
    required String icon,
    required String colorHex,
    required String direction,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final maxOrder = await db.rawQuery(
        'SELECT COALESCE(MAX(sort_order), 0) AS m FROM expense_categories WHERE is_custom = 1');
    final base = (maxOrder.first['m'] as int? ?? 0);
    final cat = ExpenseCategory(
      code: 'custom_${_uuid.v4().substring(0, 8)}',
      label: label.trim(),
      icon: icon.isEmpty ? '🏷️' : icon,
      colorHex: colorHex,
      direction: direction,
      isCustom: true,
      sortOrder: base < 300 ? 300 : base + 1,
    );
    await db.insert('expense_categories', cat.toMap());
    return cat;
  }

  static Future<void> update(ExpenseCategory cat) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('expense_categories', cat.toMap(),
        where: 'code = ?', whereArgs: [cat.code]);
  }

  static Future<void> setActive(String code, bool active) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('expense_categories', {'is_active': active ? 1 : 0},
        where: 'code = ?', whereArgs: [code]);
  }

  /// Persiste un nouvel ordre (liste de codes dans l'ordre voulu).
  static Future<void> reorder(List<String> codesInOrder) async {
    final db = await DatabaseHelper.instance.database;
    final batch = db.batch();
    for (var i = 0; i < codesInOrder.length; i++) {
      batch.update('expense_categories', {'sort_order': (i + 1) * 10},
          where: 'code = ?', whereArgs: [codesInOrder[i]]);
    }
    await batch.commit(noResult: true);
  }

  // ---------------------------------------------------------------------------
  // Catégorisation d'une transaction
  // ---------------------------------------------------------------------------

  /// Range une transaction dans une catégorie (ou `null` pour dé-catégoriser).
  /// Si [rememberFor] est fourni, mémorise aussi une règle
  /// « ce numéro / ce nom → cette catégorie » pour les prochains SMS.
  static Future<void> setTransactionCategory(
    String transactionId, {
    String? category,
    String? note,
    ({String matchType, String matchValue})? rememberFor,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final data = <String, Object?>{'category': category};
    if (note != null) data['note'] = note.trim().isEmpty ? null : note.trim();
    await db.update('transactions', data,
        where: 'id = ?', whereArgs: [transactionId]);
    if (rememberFor != null && category != null && category.isNotEmpty) {
      await upsertRule(
        matchType: rememberFor.matchType,
        matchValue: rememberFor.matchValue,
        category: category,
      );
    }
  }

  /// Nombre de transactions non catégorisées (par défaut : dépenses seules —
  /// c'est ce qui a une vraie valeur analytique pour un particulier).
  static Future<int> uncategorizedCount({String? direction = 'out'}) async {
    final db = await DatabaseHelper.instance.database;
    final dirClause = direction != null ? 'AND direction = ?' : '';
    final rows = await db.rawQuery('''
      SELECT COUNT(*) AS c FROM transactions
      WHERE status = 'completed' AND (category IS NULL OR category = '') $dirClause
    ''', direction != null ? [direction] : []);
    return (rows.first['c'] as int?) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Règles d'auto-catégorisation
  // ---------------------------------------------------------------------------

  static Future<void> upsertRule({
    required String matchType, // 'phone' | 'name' | 'type'
    required String matchValue,
    required String category,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final value = matchValue.trim().toLowerCase();
    if (value.isEmpty) return;
    await db.insert(
      'category_rules',
      {
        'id': _uuid.v4(),
        'match_type': matchType,
        'match_value': value,
        'category': category,
        'created_at': DateTime.now().toIso8601String(),
      },
      // idx_category_rules_match est UNIQUE (match_type, match_value)
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, Object?>>> getRules() async {
    final db = await DatabaseHelper.instance.database;
    return db.query('category_rules', orderBy: 'created_at DESC');
  }

  static Future<void> deleteRule(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('category_rules', where: 'id = ?', whereArgs: [id]);
  }

  /// Catégorie déduite automatiquement pour une transaction fraîchement
  /// détectée — sans jamais déranger l'utilisateur. Renvoie `null` si rien
  /// de sûr ne se dégage (→ la transaction reste « à catégoriser »).
  ///
  /// Ordre : type évident (crédit téléphone) → règle sur le numéro → règle
  /// sur le nom → règle sur le type.
  static Future<String?> autoCategoryFor({
    String? transactionTypeCode,
    String? clientPhone,
    String? clientName,
    String? direction,
  }) async {
    final code = transactionTypeCode?.toLowerCase() ?? '';
    if (code.contains('credit') || code.contains('crédit')) {
      return kCategoryCreditTel;
    }

    final db = await DatabaseHelper.instance.database;
    final rules = await db.query('category_rules');
    if (rules.isEmpty) return null;

    final phone = clientPhone?.trim().toLowerCase();
    final name = clientName?.trim().toLowerCase();

    // Numéro : correspondance exacte, la plus fiable.
    if (phone != null && phone.isNotEmpty) {
      for (final r in rules) {
        if (r['match_type'] == 'phone' &&
            (r['match_value'] as String) == phone) {
          return r['category'] as String;
        }
      }
    }
    // Nom : le nom du bénéficiaire contient la valeur de la règle.
    if (name != null && name.isNotEmpty) {
      for (final r in rules) {
        if (r['match_type'] == 'name' &&
            name.contains(r['match_value'] as String)) {
          return r['category'] as String;
        }
      }
    }
    // Type : « tous les <code> vont dans <catégorie> ».
    if (code.isNotEmpty) {
      for (final r in rules) {
        if (r['match_type'] == 'type' &&
            (r['match_value'] as String) == code) {
          return r['category'] as String;
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Budgets mensuels
  // ---------------------------------------------------------------------------

  static Future<Map<String, double>> getBudgets() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.query('category_budgets');
    return {
      for (final r in rows)
        r['category'] as String: (r['monthly_limit'] as num).toDouble()
    };
  }

  static Future<void> setBudget(String category, double monthlyLimit) async {
    final db = await DatabaseHelper.instance.database;
    if (monthlyLimit <= 0) {
      await db.delete('category_budgets',
          where: 'category = ?', whereArgs: [category]);
      return;
    }
    await db.insert(
      'category_budgets',
      {
        'category': category,
        'monthly_limit': monthlyLimit,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
