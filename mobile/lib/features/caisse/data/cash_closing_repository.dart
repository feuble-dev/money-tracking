import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';

/// Chiffres d'une journée d'agence, du point de vue des espèces : une
/// opération entrante (dépôt du client, D1 `in`) fait entrer des espèces
/// dans la caisse de l'agent ; une sortante (retrait) en fait sortir.
class CashDay {
  final DateTime day;
  final int operations;
  final double totalIn;
  final double totalOut;
  final double commissions;

  const CashDay({
    required this.day,
    required this.operations,
    required this.totalIn,
    required this.totalOut,
    required this.commissions,
  });

  double expected(double opening) => opening + totalIn - totalOut;
}

class CashClosing {
  final String day;
  final double opening;
  final double expected;
  final double counted;
  final String? note;

  const CashClosing({
    required this.day,
    required this.opening,
    required this.expected,
    required this.counted,
    this.note,
  });

  /// Positif : espèces en trop ; négatif : il en manque.
  double get gap => counted - expected;

  factory CashClosing.fromMap(Map<String, Object?> m) => CashClosing(
        day: m['day'] as String,
        opening: (m['opening'] as num).toDouble(),
        expected: (m['expected'] as num).toDouble(),
        counted: (m['counted'] as num).toDouble(),
        note: m['note'] as String?,
      );
}

/// Clôture de caisse quotidienne (Agence). Statique et sans Riverpod,
/// comme CaisseRepository.
class CashClosingRepository {
  CashClosingRepository._();

  static Future<Database> get _db => DatabaseHelper.instance.database;

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// Opérations terminées de [day] (les annulées ne déplacent pas d'espèces).
  static Future<CashDay> summarize(DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final r = (await (await _db).rawQuery('''
      SELECT COUNT(*) AS n,
             COALESCE(SUM(CASE WHEN direction = 'in' THEN amount END), 0) AS total_in,
             COALESCE(SUM(CASE WHEN direction = 'out' THEN amount END), 0) AS total_out,
             COALESCE(SUM(commission), 0) AS commissions
      FROM transactions
      WHERE status = 'completed' AND created_at >= ? AND created_at < ?
    ''', [start.toIso8601String(), end.toIso8601String()])).first;
    return CashDay(
      day: start,
      operations: (r['n'] as num).toInt(),
      totalIn: (r['total_in'] as num).toDouble(),
      totalOut: (r['total_out'] as num).toDouble(),
      commissions: (r['commissions'] as num).toDouble(),
    );
  }

  static Future<CashClosing?> forDay(DateTime day) async {
    final rows = await (await _db)
        .query('cash_closings', where: 'day = ?', whereArgs: [dayKey(day)]);
    return rows.isEmpty ? null : CashClosing.fromMap(rows.first);
  }

  /// Espèces de départ proposées pour [day] : le compté de la dernière
  /// clôture antérieure, ou 0 la première fois.
  static Future<double> suggestedOpening(DateTime day) async {
    final rows = await (await _db).query('cash_closings',
        columns: ['counted'],
        where: 'day < ?',
        whereArgs: [dayKey(day)],
        orderBy: 'day DESC',
        limit: 1);
    return rows.isEmpty ? 0 : (rows.first['counted'] as num).toDouble();
  }

  /// Enregistre (ou remplace) la clôture de [day].
  static Future<CashClosing> save({
    required DateTime day,
    required double opening,
    required double counted,
    String? note,
  }) async {
    final s = await summarize(day);
    final closing = CashClosing(
      day: dayKey(day),
      opening: opening,
      expected: s.expected(opening),
      counted: counted,
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
    );
    await (await _db).insert(
      'cash_closings',
      {
        'id': const Uuid().v4(),
        'day': closing.day,
        'opening': opening,
        'total_in': s.totalIn,
        'total_out': s.totalOut,
        'expected': closing.expected,
        'counted': counted,
        'note': closing.note,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return closing;
  }

  static Future<List<CashClosing>> history({int limit = 14}) async {
    final rows = await (await _db)
        .query('cash_closings', orderBy: 'day DESC', limit: limit);
    return rows.map(CashClosing.fromMap).toList();
  }
}
