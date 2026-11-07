import 'package:sqflite/sqflite.dart';

/// Période affichée sur l'écran Commissions.
enum CommissionPeriod { today, week, month, all }

extension CommissionPeriodX on CommissionPeriod {
  String get label => switch (this) {
        CommissionPeriod.today => "Aujourd'hui",
        CommissionPeriod.week => '7 jours',
        CommissionPeriod.month => 'Ce mois',
        CommissionPeriod.all => 'Tout',
      };

  /// Début de la période (null = depuis toujours).
  DateTime? since(DateTime now) => switch (this) {
        CommissionPeriod.today => DateTime(now.year, now.month, now.day),
        CommissionPeriod.week => DateTime(now.year, now.month, now.day - 6),
        CommissionPeriod.month => DateTime(now.year, now.month, 1),
        CommissionPeriod.all => null,
      };
}

class CommissionLine {
  final String key;
  final String label;
  final double commission;
  final double volume;
  final int count;

  const CommissionLine(this.key, this.label, this.commission, this.volume, this.count);
}

class CommissionStats {
  final double total;
  final double volume;
  final int count;
  /// Par type de service (Dépôt, Retrait, Paiement marchand…), du plus
  /// rentable au moins rentable.
  final List<CommissionLine> byService;
  final List<CommissionLine> byOperator;
  /// Commissions des 14 derniers jours, du plus ancien au plus récent
  /// (indépendant de la période choisie).
  final List<double> last14Days;
  final Map<String, double> soldes;

  const CommissionStats({
    required this.total,
    required this.volume,
    required this.count,
    required this.byService,
    required this.byOperator,
    required this.last14Days,
    required this.soldes,
  });

  double get perOperation => count == 0 ? 0 : total / count;
}

/// Toutes les statistiques de l'écran Commissions en quelques requêtes
/// indexées (transactions terminées uniquement). Séparé de l'UI pour être
/// testable.
Future<CommissionStats> loadCommissionStats(
  DatabaseExecutor db,
  CommissionPeriod period, {
  DateTime? now,
}) async {
  final today = now ?? DateTime.now();
  final since = period.since(today);
  final where = StringBuffer("t.status = 'completed'");
  final args = <Object?>[];
  if (since != null) {
    where.write(' AND t.created_at >= ?');
    args.add(since.toIso8601String());
  }

  final total = (await db.rawQuery('''
    SELECT COALESCE(SUM(t.commission), 0) AS c, COALESCE(SUM(t.amount), 0) AS v, COUNT(*) AS n
    FROM transactions t WHERE $where
  ''', args)).first;

  List<CommissionLine> lines(List<Map<String, Object?>> rows) => [
        for (final r in rows)
          CommissionLine(
            '${r['k']}',
            (r['label'] as String?) ?? 'Autre',
            (r['c'] as num).toDouble(),
            (r['v'] as num).toDouble(),
            (r['n'] as num).toInt(),
          ),
      ];

  final byService = lines(await db.rawQuery('''
    SELECT COALESCE(t.transaction_type_id, t.transaction_type) AS k,
           COALESCE(tt.label, t.transaction_type) AS label,
           COALESCE(SUM(t.commission), 0) AS c, COALESCE(SUM(t.amount), 0) AS v, COUNT(*) AS n
    FROM transactions t
    LEFT JOIN transaction_types tt ON tt.id = t.transaction_type_id
    WHERE $where
    GROUP BY k ORDER BY c DESC, n DESC
  ''', args));

  final byOperator = lines(await db.rawQuery('''
    SELECT o.id AS k, o.name AS label,
           COALESCE(SUM(t.commission), 0) AS c, COALESCE(SUM(t.amount), 0) AS v, COUNT(t.id) AS n
    FROM operators o
    LEFT JOIN transactions t ON t.operator_id = o.id AND $where
    WHERE o.is_active = 1
    GROUP BY o.id ORDER BY c DESC
  ''', args));

  final start14 = DateTime(today.year, today.month, today.day - 13);
  final daily = await db.rawQuery('''
    SELECT substr(created_at, 1, 10) AS d, COALESCE(SUM(commission), 0) AS c
    FROM transactions
    WHERE status = 'completed' AND created_at >= ?
    GROUP BY d
  ''', [start14.toIso8601String()]);
  final byDay = {for (final r in daily) r['d'] as String: (r['c'] as num).toDouble()};
  final last14 = [
    for (var i = 0; i < 14; i++)
      byDay[DateTime(start14.year, start14.month, start14.day + i)
              .toIso8601String()
              .substring(0, 10)] ??
          0,
  ];

  final soldeRows = await db.rawQuery(
      'SELECT operator_id, SUM(solde_actuel) AS s FROM caisse '
      'WHERE operator_id IS NOT NULL GROUP BY operator_id');

  return CommissionStats(
    total: (total['c'] as num).toDouble(),
    volume: (total['v'] as num).toDouble(),
    count: (total['n'] as num).toInt(),
    byService: byService,
    byOperator: byOperator,
    last14Days: last14,
    soldes: {
      for (final r in soldeRows) r['operator_id'] as String: (r['s'] as num?)?.toDouble() ?? 0,
    },
  );
}
