import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import 'dashboard_provider.dart' show dashboardFilterProvider;

/// Sentinelle pour la tranche « Non catégorisé » du camembert des dépenses.
const kUncategorizedBucket = '__uncat__';

class CategorySpend {
  final String code; // code catégorie, ou kUncategorizedBucket
  final double amount;
  final int count;
  const CategorySpend(this.code, this.amount, this.count);
}

class BeneficiarySpend {
  final String label;
  final String phone;
  final double amount;
  final int count;
  const BeneficiarySpend(this.label, this.phone, this.amount, this.count);
}

/// Stats du tableau de bord **Particulier** — orientées finances perso
/// (dépenses par motif, à qui je donne, évolution), là où
/// [DashboardStats] est orienté activité d'agent (caisse, commissions,
/// classement opérateurs, clients).
class ParticulierDashboardStats {
  final double totalIn;
  final double totalOut;
  final int txCountOut;
  final double prevOut; // même durée, période précédente — pour la tendance
  final List<CategorySpend> byCategory; // dépenses, triées desc
  final List<Map<String, dynamic>> byOperator; // {id,name,out,in,count}
  final List<BeneficiarySpend> topBeneficiaries;
  final List<Map<String, dynamic>> dailyOut; // {date, out}

  const ParticulierDashboardStats({
    this.totalIn = 0,
    this.totalOut = 0,
    this.txCountOut = 0,
    this.prevOut = 0,
    this.byCategory = const [],
    this.byOperator = const [],
    this.topBeneficiaries = const [],
    this.dailyOut = const [],
  });

  double get net => totalIn - totalOut;

  double get outTrend {
    if (prevOut == 0) return totalOut > 0 ? 100 : 0;
    return ((totalOut - prevOut) / prevOut) * 100;
  }

  double get uncategorizedOut => byCategory
      .where((c) => c.code == kUncategorizedBucket)
      .fold(0.0, (s, c) => s + c.amount);
}

final particulierDashboardProvider =
    FutureProvider.family<ParticulierDashboardStats, String?>(
        (ref, operatorId) async {
  final filter = ref.watch(dashboardFilterProvider);
  final (start, end) = filter.effectiveRange;
  final db = await DatabaseHelper.instance.database;

  final startIso = start.toIso8601String();
  final endIso = end.toIso8601String();
  final periodDuration = end.difference(start);
  final prevStart = start.subtract(periodDuration).toIso8601String();
  final prevEnd = start.toIso8601String();

  final opClause = operatorId != null ? 'AND t.operator_id = ?' : '';
  List<Object?> args([List<Object?> extra = const []]) =>
      [...extra, ?operatorId];

  final results = await Future.wait([
    // [0] Totaux entrées / sorties + nb dépenses
    db.rawQuery('''
      SELECT
        COALESCE(SUM(CASE WHEN direction='in' THEN amount ELSE 0 END), 0) AS tin,
        COALESCE(SUM(CASE WHEN direction='out' THEN amount ELSE 0 END), 0) AS tout,
        COALESCE(SUM(CASE WHEN direction='out' THEN 1 ELSE 0 END), 0) AS cout
      FROM transactions t
      WHERE t.status='completed' AND t.created_at BETWEEN ? AND ? $opClause
    ''', args([startIso, endIso])),
    // [1] Dépenses par motif
    db.rawQuery('''
      SELECT COALESCE(NULLIF(t.category, ''), '$kUncategorizedBucket') AS cat,
             COALESCE(SUM(t.amount), 0) AS total, COUNT(*) AS c
      FROM transactions t
      WHERE t.status='completed' AND t.direction='out'
        AND t.created_at BETWEEN ? AND ? $opClause
      GROUP BY cat ORDER BY total DESC
    ''', args([startIso, endIso])),
    // [2] Répartition par opérateur
    db.rawQuery('''
      SELECT o.id, o.name,
        COALESCE(SUM(CASE WHEN t.direction='out' THEN t.amount ELSE 0 END), 0) AS tout,
        COALESCE(SUM(CASE WHEN t.direction='in' THEN t.amount ELSE 0 END), 0) AS tin,
        COUNT(*) AS c
      FROM transactions t JOIN operators o ON o.id = t.operator_id
      WHERE t.status='completed' AND t.created_at BETWEEN ? AND ? $opClause
      GROUP BY o.id ORDER BY tout DESC
    ''', args([startIso, endIso])),
    // [3] Top bénéficiaires (dépenses)
    db.rawQuery('''
      SELECT COALESCE(NULLIF(t.client_name, ''), t.client_phone) AS label,
             t.client_phone AS phone,
             COALESCE(SUM(t.amount), 0) AS total, COUNT(*) AS c
      FROM transactions t
      WHERE t.status='completed' AND t.direction='out'
        AND t.created_at BETWEEN ? AND ? $opClause
        AND (t.client_phone != '' OR t.client_name IS NOT NULL)
      GROUP BY label ORDER BY total DESC LIMIT 6
    ''', args([startIso, endIso])),
    // [4] Dépenses quotidiennes
    db.rawQuery('''
      SELECT DATE(t.created_at) AS day,
             COALESCE(SUM(t.amount), 0) AS tout
      FROM transactions t
      WHERE t.status='completed' AND t.direction='out'
        AND t.created_at BETWEEN ? AND ? $opClause
      GROUP BY day ORDER BY day ASC
    ''', args([startIso, endIso])),
    // [5] Dépenses période précédente (tendance)
    db.rawQuery('''
      SELECT COALESCE(SUM(t.amount), 0) AS tout
      FROM transactions t
      WHERE t.status='completed' AND t.direction='out'
        AND t.created_at >= ? AND t.created_at < ? $opClause
    ''', args([prevStart, prevEnd])),
  ]);

  final tot = results[0].first;
  final byCategory = results[1]
      .map((r) => CategorySpend(r['cat'] as String,
          (r['total'] as num).toDouble(), (r['c'] as num).toInt()))
      .toList();
  final byOperator = results[2]
      .map((r) => {
            'id': r['id'],
            'name': r['name'],
            'out': (r['tout'] as num).toDouble(),
            'in': (r['tin'] as num).toDouble(),
            'count': (r['c'] as num).toInt(),
          })
      .toList();
  final topBen = results[3]
      .map((r) => BeneficiarySpend(
            (r['label'] as String?) ?? '—',
            (r['phone'] as String?) ?? '',
            (r['total'] as num).toDouble(),
            (r['c'] as num).toInt(),
          ))
      .toList();

  // Remplissage jour par jour pour un graphe continu.
  final dailyMap = {
    for (final r in results[4])
      r['day'] as String: (r['tout'] as num).toDouble()
  };
  final totalDays = end.difference(start).inDays + 1;
  final dailyOut = <Map<String, dynamic>>[];
  for (var i = 0; i < totalDays && i < 120; i++) {
    final d = DateTime(start.year, start.month, start.day + i);
    final key =
        '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    dailyOut.add({'date': d, 'out': dailyMap[key] ?? 0.0});
  }

  return ParticulierDashboardStats(
    totalIn: (tot['tin'] as num).toDouble(),
    totalOut: (tot['tout'] as num).toDouble(),
    txCountOut: (tot['cout'] as num).toInt(),
    prevOut: (results[5].first['tout'] as num).toDouble(),
    byCategory: byCategory,
    byOperator: byOperator,
    topBeneficiaries: topBen,
    dailyOut: dailyOut,
  );
});
