import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/transaction_repository.dart';
import '../models/dashboard_filter.dart';

/// Statistiques enrichies du dashboard
class DashboardStats {
  final double totalDeposits;
  final double totalWithdrawals;
  final int transactionCount;
  final int uniqueClients;
  final double avgDepositAmount;
  final double avgWithdrawalAmount;
  final double avgDailyVolume;
  final double maxDeposit;
  final double maxWithdrawal;
  final String? busiestDay;
  final int busiestDayCount;
  final int? busiestHour;
  final double depositTrend;
  final double withdrawalTrend;
  final List<Map<String, dynamic>> dailyStats;
  final List<Map<String, dynamic>> hourlyStats;
  final List<Map<String, dynamic>> operatorStats;
  final double todayDeposits;
  final double todayWithdrawals;
  final int todayCount;
  final int todayClients;

  const DashboardStats({
    this.totalDeposits = 0,
    this.totalWithdrawals = 0,
    this.transactionCount = 0,
    this.uniqueClients = 0,
    this.avgDepositAmount = 0,
    this.avgWithdrawalAmount = 0,
    this.avgDailyVolume = 0,
    this.maxDeposit = 0,
    this.maxWithdrawal = 0,
    this.busiestDay,
    this.busiestDayCount = 0,
    this.busiestHour,
    this.depositTrend = 0,
    this.withdrawalTrend = 0,
    this.dailyStats = const [],
    this.hourlyStats = const [],
    this.operatorStats = const [],
    this.todayDeposits = 0,
    this.todayWithdrawals = 0,
    this.todayCount = 0,
    this.todayClients = 0,
  });

  double get depositRatio => transactionCount > 0
      ? (totalDeposits / (totalDeposits + totalWithdrawals)) * 100
      : 0;
}

/// Provider pour le filtre dashboard
final dashboardFilterProvider =
    StateProvider<DashboardFilter>((ref) => const DashboardFilter());

/// Provider principal des stats — optimisé avec requêtes parallèles
final dashboardStatsProvider =
    FutureProvider.family<DashboardStats, String?>((ref, operatorIdOverride) async {
  final filter = ref.watch(dashboardFilterProvider);
  final effectiveOpId = operatorIdOverride;
  final (start, end) = filter.effectiveRange;

  final startDay = _dateToKey(start);
  final endDay = _dateToKey(end);
  final repo = TransactionRepository.instance;
  final db = await DatabaseHelper.instance.database;
  final todayKey = _dateToKey(DateTime.now());

  // Requêtes parallèles : période + today + daily + hourly + opérateurs + tendance
  final periodDuration = end.difference(start);
  final prevStart = start.subtract(periodDuration);
  final prevEnd = start.subtract(const Duration(days: 1));

  final opFilter = effectiveOpId != null ? 'AND operator_id = ?' : '';
  final opArgs = effectiveOpId != null ? [effectiveOpId] : <String>[];

  final futures = await Future.wait([
    // [0] Totaux période
    repo.getPeriodStats(startDate: startDay, endDate: endDay, operatorId: effectiveOpId),
    // [1] Stats du jour
    repo.getPeriodStats(startDate: todayKey, endDate: todayKey, operatorId: effectiveOpId),
    // [2] Stats quotidiennes
    repo.getDailySummaries(startDate: startDay, endDate: endDay, operatorId: effectiveOpId),
    // [3] Stats horaires
    db.rawQuery('''
      SELECT CAST(strftime('%H', created_at) AS INTEGER) as hour, COUNT(*) as tx_count
      FROM transactions
      WHERE status='completed' AND created_at BETWEEN ? AND ? $opFilter
      GROUP BY hour ORDER BY hour ASC
    ''', [start.toIso8601String(), end.toIso8601String(), ...opArgs]),
    // [4] Stats par opérateur
    repo.getOperatorStats(startDate: startDay, endDate: endDay),
    // [5] Tendance période précédente
    repo.getPeriodStats(startDate: _dateToKey(prevStart), endDate: _dateToKey(prevEnd), operatorId: effectiveOpId),
  ]);

  final periodStats = futures[0] as Map<String, dynamic>;
  final ts = futures[1] as Map<String, dynamic>;
  final dailyRaw = futures[2] as List<Map<String, dynamic>>;
  final hourlyRaw = futures[3] as List<Map<String, dynamic>>;
  final operatorStats = futures[4] as List<Map<String, dynamic>>;
  final prevStats = futures[5] as Map<String, dynamic>;

  // Extraction période
  final totalDeposits = (periodStats['deposit_total'] as num).toDouble();
  final totalWithdrawals = (periodStats['withdrawal_total'] as num).toDouble();
  final depCount = (periodStats['deposit_count'] as num).toInt();
  final witCount = (periodStats['withdrawal_count'] as num).toInt();
  final txCount = depCount + witCount;
  final uniqueClients = (periodStats['unique_clients'] as num).toInt();
  final maxDep = (periodStats['max_deposit'] as num).toDouble();
  final maxWit = (periodStats['max_withdrawal'] as num).toDouble();
  final avgDep = depCount > 0 ? totalDeposits / depCount : 0.0;
  final avgWit = witCount > 0 ? totalWithdrawals / witCount : 0.0;

  // Stats quotidiennes
  final dailyMap = <String, Map<String, dynamic>>{};
  for (final row in dailyRaw) {
    final day = row['day'] as String;
    dailyMap[day] = {
      'deposits': (row['deposit_total'] as num).toDouble(),
      'withdrawals': (row['withdrawal_total'] as num).toDouble(),
      'count': (row['deposit_count'] as num).toInt() + (row['withdrawal_count'] as num).toInt(),
    };
  }

  final totalDays = end.difference(start).inDays + 1;
  final dailyStats = <Map<String, dynamic>>[];
  String? busiestDay;
  int busiestDayCount = 0;

  for (int i = 0; i < totalDays; i++) {
    final date = DateTime(start.year, start.month, start.day + i);
    final key = _dateToKey(date);
    final dayData = dailyMap[key];
    final count = (dayData?['count'] as int?) ?? 0;
    dailyStats.add({
      'date': date,
      'deposits': dayData?['deposits'] ?? 0.0,
      'withdrawals': dayData?['withdrawals'] ?? 0.0,
      'count': count,
    });
    if (count > busiestDayCount) {
      busiestDayCount = count;
      busiestDay = key;
    }
  }

  // Stats horaires
  final hourlyMap = <int, int>{};
  int? busiestHour;
  int busiestHourCount = 0;
  for (final row in hourlyRaw) {
    final hour = row['hour'] as int;
    final count = row['tx_count'] as int;
    hourlyMap[hour] = count;
    if (count > busiestHourCount) {
      busiestHourCount = count;
      busiestHour = hour;
    }
  }
  final hourlyStats = <Map<String, dynamic>>[
    for (int h = 6; h <= 22; h++) {'hour': h, 'count': hourlyMap[h] ?? 0},
  ];

  // Tendance
  final prevDeposits = (prevStats['deposit_total'] as num).toDouble();
  final prevWithdrawals = (prevStats['withdrawal_total'] as num).toDouble();

  double calcTrend(double current, double previous) {
    if (previous == 0) return current > 0 ? 100 : 0;
    return ((current - previous) / previous) * 100;
  }

  final totalVolume = totalDeposits + totalWithdrawals;
  final effectiveDays = totalDays > 0 ? totalDays : 1;
  final todayDepCount = (ts['deposit_count'] as num).toInt();
  final todayWitCount = (ts['withdrawal_count'] as num).toInt();

  return DashboardStats(
    totalDeposits: totalDeposits,
    totalWithdrawals: totalWithdrawals,
    transactionCount: txCount,
    uniqueClients: uniqueClients,
    avgDepositAmount: avgDep,
    avgWithdrawalAmount: avgWit,
    avgDailyVolume: totalVolume / effectiveDays,
    maxDeposit: maxDep,
    maxWithdrawal: maxWit,
    busiestDay: busiestDay,
    busiestDayCount: busiestDayCount,
    busiestHour: busiestHour,
    depositTrend: calcTrend(totalDeposits, prevDeposits),
    withdrawalTrend: calcTrend(totalWithdrawals, prevWithdrawals),
    dailyStats: dailyStats,
    hourlyStats: hourlyStats,
    operatorStats: List<Map<String, dynamic>>.from(operatorStats),
    todayDeposits: (ts['deposit_total'] as num).toDouble(),
    todayWithdrawals: (ts['withdrawal_total'] as num).toDouble(),
    todayCount: todayDepCount + todayWitCount,
    todayClients: (ts['unique_clients'] as num).toInt(),
  );
});

String _dateToKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
