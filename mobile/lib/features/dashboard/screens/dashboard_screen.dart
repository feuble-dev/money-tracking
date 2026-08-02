import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/sms/sms_listener.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/main_shell.dart';
import '../../operators/providers/operator_provider.dart';
import '../models/dashboard_filter.dart';
import '../providers/dashboard_provider.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/hourly_chart_widget.dart';
import '../widgets/line_chart_widget.dart';
import '../widgets/pie_chart_widget.dart';
import '../widgets/ratio_chart_widget.dart';
import '../widgets/trend_indicator.dart';

/// Écran principal du Dashboard — onglets Global + par opérateur
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final _currencyFormat =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  void _updateTabs(int operatorCount) {
    final newLength = operatorCount + 1;
    if (_tabController.length != newLength) {
      _tabController.dispose();
      _tabController = TabController(length: newLength, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final operatorsAsync = ref.watch(operatorsProvider);
    final filter = ref.watch(dashboardFilterProvider);

    return operatorsAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur: $e'))),
      data: (operators) {
        final activeOps = operators.where((o) => o.isActive).toList();
        _updateTabs(activeOps.length);

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
            ),
            title: const Text('MoneyTracking'),
            actions: [
              // Indicateur service SMS
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Consumer(builder: (_, ref, _) {
                  final active = ref.watch(smsServiceActiveProvider);
                  return Tooltip(
                    message: active ? 'SMS actif' : 'SMS inactif',
                    child: Icon(Icons.circle,
                        size: 10,
                        color: active ? Colors.greenAccent : Colors.red),
                  );
                }),
              ),
              Consumer(builder: (_, ref, _) {
                final count = ref.watch(pendingNotifCountProvider);
                return IconButton(
                  icon: Badge(
                    isLabelVisible: count > 0,
                    label: Text(count.toString()),
                    backgroundColor: AppColors.accentColor,
                    child: const Icon(Icons.notifications_outlined),
                  ),
                  onPressed: () => context.push('/notifications'),
                );
              }),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => context.push('/settings'),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(90),
              child: Column(
                children: [
                  _buildPeriodSelector(filter),
                  TabBar(
                    controller: _tabController,
                    isScrollable: activeOps.length > 3,
                    indicatorColor: Colors.white,
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white70,
                    tabs: [
                      const Tab(text: 'Global'),
                      ...activeOps.map((op) => Tab(text: op.name)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _DashboardTab(
                operatorId: null,
                currencyFormat: _currencyFormat,
              ),
              ...activeOps.map((op) => _DashboardTab(
                    operatorId: op.id,
                    currencyFormat: _currencyFormat,
                  )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPeriodSelector(DashboardFilter filter) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          // Bouton "Tout" (effacer le filtre)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text('Tout',
                  style: TextStyle(
                    fontSize: 12,
                    color: !filter.hasFilter ? Colors.white : AppColors.primaryDark,
                  )),
              selected: !filter.hasFilter,
              selectedColor: AppColors.accentColor,
              backgroundColor: Colors.white.withAlpha(200),
              side: BorderSide.none,
              onSelected: (_) {
                ref.read(dashboardFilterProvider.notifier).state =
                    filter.copyWith(period: () => null);
              },
            ),
          ),
          ...DashboardPeriod.values
              .where((p) => p != DashboardPeriod.custom)
              .map((period) {
            final isSelected = filter.period == period;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(period.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected ? Colors.white : AppColors.primaryDark,
                    )),
                selected: isSelected,
                selectedColor: AppColors.primaryDark,
                backgroundColor: Colors.white.withAlpha(200),
                side: BorderSide.none,
                onSelected: (_) {
                  ref.read(dashboardFilterProvider.notifier).state =
                      filter.copyWith(period: () => period);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Contenu d'un onglet dashboard (Global ou opérateur)
class _DashboardTab extends ConsumerWidget {
  final String? operatorId;
  final NumberFormat currencyFormat;

  const _DashboardTab({
    required this.operatorId,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(dashboardStatsProvider(operatorId));

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (stats) {
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardStatsProvider(operatorId));
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildTodaySection(context, stats),
              const SizedBox(height: 20),
              _buildPeriodSummary(context, stats),
              const SizedBox(height: 20),
              _chartCard(
                context,
                'Ratio dépôts / retraits',
                SizedBox(
                  height: 180,
                  child: RatioChartWidget(
                    deposits: stats.totalDeposits,
                    withdrawals: stats.totalWithdrawals,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _chartCard(
                context,
                'Évolution dépôts vs retraits',
                SizedBox(
                  height: 220,
                  child: LineChartWidget(data: stats.dailyStats),
                ),
              ),
              const SizedBox(height: 16),
              _chartCard(
                context,
                'Volume quotidien',
                SizedBox(
                  height: 220,
                  child: BarChartWidget(data: stats.dailyStats),
                ),
              ),
              const SizedBox(height: 16),
              if (stats.hourlyStats.isNotEmpty)
                _chartCard(
                  context,
                  'Heures d\'activité',
                  HourlyChartWidget(data: stats.hourlyStats),
                ),
              if (operatorId == null && stats.operatorStats.isNotEmpty) ...[
                const SizedBox(height: 16),
                _chartCard(
                  context,
                  'Répartition par opérateur',
                  SizedBox(
                    height: 220,
                    child: PieChartWidget(data: stats.operatorStats),
                  ),
                ),
                const SizedBox(height: 16),
                _buildOperatorRanking(context, stats),
              ],
              const SizedBox(height: 16),
              _buildDetailedStats(context, stats),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTodaySection(BuildContext context, DashboardStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Aujourd\'hui',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const Spacer(),
            Text(
              '${stats.todayCount} transaction${stats.todayCount > 1 ? 's' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _miniStat(
                Icons.arrow_downward, 'Dépôts',
                currencyFormat.format(stats.todayDeposits),
                AppColors.depositColor)),
            const SizedBox(width: 10),
            Expanded(child: _miniStat(
                Icons.arrow_upward, 'Retraits',
                currencyFormat.format(stats.todayWithdrawals),
                AppColors.withdrawColor)),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodSummary(BuildContext context, DashboardStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Résumé période',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.arrow_downward,
                  size: 16, color: AppColors.depositColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Dépôts: ${currencyFormat.format(stats.totalDeposits)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.depositColor,
                      fontSize: 14),
                ),
              ),
              TrendIndicator(percentage: stats.depositTrend, label: ''),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.arrow_upward,
                  size: 16, color: AppColors.withdrawColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Retraits: ${currencyFormat.format(stats.totalWithdrawals)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.withdrawColor,
                      fontSize: 14),
                ),
              ),
              TrendIndicator(percentage: stats.withdrawalTrend, label: ''),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              Expanded(child: _kpiTile(context,
                  '${stats.transactionCount}', 'Transactions', Icons.receipt_long)),
              Expanded(child: _kpiTile(context,
                  '${stats.uniqueClients}', 'Clients', Icons.people)),
              Expanded(child: _kpiTile(context,
                  currencyFormat.format(stats.netBalance),
                  'Solde net', Icons.account_balance_wallet)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOperatorRanking(BuildContext context, DashboardStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Classement opérateurs',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
          const SizedBox(height: 12),
          ...stats.operatorStats.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value;
            final deposits = (d['deposits'] as num).toDouble();
            final withdrawals = (d['withdrawals'] as num).toDouble();
            final total = (d['total'] as num).toDouble();
            final txCount = d['tx_count'] as int;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primaryColor.withAlpha(30),
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['name'] as String,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(
                          '$txCount tx — ${currencyFormat.format(total)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('+${currencyFormat.format(deposits)}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.depositColor,
                              fontWeight: FontWeight.w500)),
                      Text('-${currencyFormat.format(withdrawals)}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.withdrawColor,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDetailedStats(BuildContext context, DashboardStats stats) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Statistiques détaillées',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  )),
          const SizedBox(height: 12),
          _statRow(context, 'Dépôt moyen', currencyFormat.format(stats.avgDepositAmount)),
          _statRow(context, 'Retrait moyen', currencyFormat.format(stats.avgWithdrawalAmount)),
          _statRow(context, 'Volume quotidien moyen', currencyFormat.format(stats.avgDailyVolume)),
          _statRow(context, 'Plus gros dépôt', currencyFormat.format(stats.maxDeposit)),
          _statRow(context, 'Plus gros retrait', currencyFormat.format(stats.maxWithdrawal)),
          if (stats.busiestHour != null)
            _statRow(context, 'Heure de pointe', '${stats.busiestHour}h00'),
          if (stats.busiestDay != null)
            _statRow(context, 'Jour le plus actif',
                '${stats.busiestDay} (${stats.busiestDayCount} tx)'),
        ],
      ),
    );
  }

  Widget _statRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Text(value, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 12, color: color)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _kpiTile(BuildContext context, String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
        Text(label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center),
      ],
    );
  }

  Widget _chartCard(BuildContext context, String title, Widget chart) {
    return RepaintBoundary(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 16),
            chart,
          ],
        ),
      ),
    );
  }
}
