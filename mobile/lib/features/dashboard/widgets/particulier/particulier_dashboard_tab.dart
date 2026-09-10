import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/categories/category_providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../caisse/providers/caisse_provider.dart';
import '../../providers/particulier_dashboard_provider.dart';
import '../../screens/dashboard_screen.dart' show balanceVisibleProvider;
import '../bar_chart_widget.dart';
import '../trend_indicator.dart';

/// Contenu d'un onglet du tableau de bord **Particulier** (Global ou un
/// opérateur). Orienté finances personnelles : vue du mois, portefeuilles
/// Mobile Money, dépenses par motif, à qui je donne, évolution. Gaté depuis
/// `DashboardScreen` par `accountTypeProvider` — on ne duplique pas l'écran
/// (même convention que D7/D18).
class ParticulierDashboardTab extends ConsumerWidget {
  final String? operatorId;
  final NumberFormat currencyFormat;

  const ParticulierDashboardTab({
    super.key,
    required this.operatorId,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(particulierDashboardProvider(operatorId));

    return statsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (stats) {
        final empty = stats.totalIn == 0 &&
            stats.totalOut == 0 &&
            stats.byOperator.isEmpty;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(particulierDashboardProvider(operatorId));
            ref.read(caissesProvider.notifier).load();
          },
          child: empty
              ? _EmptyState(operatorId: operatorId)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
            _OverviewCard(stats: stats, currency: currencyFormat),
            const SizedBox(height: 16),
            _WalletsCard(operatorId: operatorId, currency: currencyFormat),
            const SizedBox(height: 16),
            const _UncatBanner(),
            _CategoryBreakdown(stats: stats, currency: currencyFormat),
            const SizedBox(height: 16),
            _card(
              context,
              'Évolution des dépenses',
              SizedBox(
                height: 200,
                child: BarChartWidget(
                  data: stats.dailyOut
                      .map((d) => {
                            'date': d['date'],
                            'deposits': 0.0,
                            'withdrawals': (d['out'] as num).toDouble(),
                            'count': 0,
                          })
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _TopBeneficiaries(stats: stats, currency: currencyFormat),
            if (operatorId == null && stats.byOperator.length > 1) ...[
              const SizedBox(height: 16),
              _OperatorSplit(stats: stats, currency: currencyFormat),
            ],
                    const SizedBox(height: 24),
                  ],
                ),
        );
      },
    );
  }

  static Widget _card(BuildContext context, String title, Widget child) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

/// Aucune activité : on guide vers la détection SMS et l'import d'historique
/// plutôt que d'afficher des graphes vides.
class _EmptyState extends StatelessWidget {
  final String? operatorId;
  const _EmptyState({this.operatorId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.insights_outlined, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(
          'Aucune activité pour l\'instant',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Vos transactions Mobile Money apparaîtront ici automatiquement, '
          'dès qu\'un SMS d\'opérateur est reçu.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: () => context.push('/settings/sms-test'),
          icon: const Icon(Icons.sms_outlined, size: 18),
          label: const Text('Vérifier la détection SMS'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => context.push('/historique/import'),
          icon: const Icon(Icons.history, size: 18),
          label: const Text('Importer mon historique SMS'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _OverviewCard extends ConsumerWidget {
  final ParticulierDashboardStats stats;
  final NumberFormat currency;

  const _OverviewCard({required this.stats, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = !ref.watch(balanceVisibleProvider);
    String m(num v) => hidden ? '••••' : currency.format(v);
    final net = stats.net;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryDark,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Ce mois',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(hidden ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white70, size: 20),
                onPressed: () => ref.read(balanceVisibleProvider.notifier).state =
                    !ref.read(balanceVisibleProvider),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                m(net.abs()),
                style: TextStyle(
                    color: net >= 0 ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 26,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(net >= 0 ? 'épargné' : 'de plus dépensé',
                    style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ),
              const Spacer(),
              TrendIndicator(percentage: stats.outTrend, label: ''),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _mini(Icons.south_west, 'Revenus', m(stats.totalIn),
                    AppColors.depositColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _mini(Icons.north_east, 'Dépenses', m(stats.totalOut),
                    Colors.orangeAccent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ]),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _WalletsCard extends ConsumerWidget {
  final String? operatorId;
  final NumberFormat currency;

  const _WalletsCard({required this.operatorId, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = !ref.watch(balanceVisibleProvider);
    final caissesAsync = ref.watch(caissesProvider);
    String m(num v) => hidden ? '••••' : currency.format(v);

    return caissesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (caisses) {
        final relevant = (operatorId == null
                ? caisses
                : caisses.where((c) => c.operatorId == operatorId))
            .toList();
        if (relevant.isEmpty) return const SizedBox.shrink();
        final total = relevant.fold<double>(0, (s, c) => s + c.soldeActuel);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Mes portefeuilles Mobile Money',
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text(m(total),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Text('Solde annoncé par le dernier SMS de chaque opérateur',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              const SizedBox(height: 8),
              ...relevant.map((c) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined,
                            size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                            child: Text(c.operatorName ?? 'Opérateur',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w500))),
                        Text(m(c.soldeActuel),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------

class _UncatBanner extends ConsumerWidget {
  const _UncatBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(uncategorizedCountProvider).valueOrNull ?? 0;
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => context.push('/categorize'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.label_outline,
                    size: 18, color: Colors.orange.shade800),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$count dépense${count > 1 ? 's' : ''} à catégoriser',
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.orange.shade900),
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18, color: Colors.orange.shade800),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _CategoryBreakdown extends ConsumerWidget {
  final ParticulierDashboardStats stats;
  final NumberFormat currency;

  const _CategoryBreakdown({required this.stats, required this.currency});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catMap = ref.watch(categoriesByCodeProvider).valueOrNull ?? {};
    final rows = stats.byCategory;
    if (rows.isEmpty) {
      return ParticulierDashboardTab._card(
        context,
        'Dépenses par motif',
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('Aucune dépense sur la période.'),
        ),
      );
    }
    final total = rows.fold<double>(0, (s, r) => s + r.amount);

    ({String label, String icon, Color color}) meta(String code) {
      if (code == kUncategorizedBucket) {
        return (label: 'Non catégorisé', icon: '❓', color: Colors.grey);
      }
      final c = catMap[code];
      return (
        label: c?.label ?? code,
        icon: c?.icon ?? '🏷️',
        color: c?.color ?? Colors.blueGrey
      );
    }

    return ParticulierDashboardTab._card(
      context,
      'Dépenses par motif',
      Column(
        children: [
          SizedBox(
            height: 160,
            child: Row(
              children: [
                SizedBox(
                  width: 150,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 34,
                      sections: [
                        for (final r in rows.take(6))
                          PieChartSectionData(
                            value: r.amount,
                            color: meta(r.code).color,
                            radius: 34,
                            showTitle: false,
                          ),
                        if (rows.length > 6)
                          PieChartSectionData(
                            value: rows
                                .skip(6)
                                .fold<double>(0, (s, r) => s + r.amount),
                            color: Colors.grey.shade400,
                            radius: 34,
                            showTitle: false,
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(currency.format(total),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('${stats.txCountOut} dépense'
                          '${stats.txCountOut > 1 ? 's' : ''}',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ...rows.take(8).map((r) {
            final mt = meta(r.code);
            final pct = total > 0 ? (r.amount / total) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: InkWell(
                onTap: () => context.push('/transactions'),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(mt.icon, style: const TextStyle(fontSize: 15)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(mt.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13))),
                        Text('${(pct * 100).round()}%',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[600])),
                        const SizedBox(width: 8),
                        Text(currency.format(r.amount),
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 5,
                        backgroundColor: Colors.grey.withAlpha(30),
                        valueColor: AlwaysStoppedAnimation(mt.color),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _TopBeneficiaries extends StatelessWidget {
  final ParticulierDashboardStats stats;
  final NumberFormat currency;

  const _TopBeneficiaries({required this.stats, required this.currency});

  @override
  Widget build(BuildContext context) {
    if (stats.topBeneficiaries.isEmpty) return const SizedBox.shrink();
    return ParticulierDashboardTab._card(
      context,
      'À qui je donne le plus',
      Column(
        children: stats.topBeneficiaries.map((b) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primaryColor.withAlpha(28),
                  child: Text(
                    b.label.isNotEmpty ? b.label[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryColor),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(b.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text('${b.count} envoi${b.count > 1 ? 's' : ''}',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Text(currency.format(b.amount),
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.withdrawColor)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _OperatorSplit extends StatelessWidget {
  final ParticulierDashboardStats stats;
  final NumberFormat currency;

  const _OperatorSplit({required this.stats, required this.currency});

  @override
  Widget build(BuildContext context) {
    final maxOut = stats.byOperator
        .fold<double>(0, (m, o) => (o['out'] as double) > m ? o['out'] as double : m);
    return ParticulierDashboardTab._card(
      context,
      'Par opérateur',
      Column(
        children: stats.byOperator.map((o) {
          final out = o['out'] as double;
          final pct = maxOut > 0 ? out / maxOut : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: Text(o['name'] as String,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w500))),
                    Text(currency.format(out),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: Colors.grey.withAlpha(30),
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primaryColor),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
