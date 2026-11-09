import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/format/formats.dart';
import '../../../core/sms/sms_listener.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../../shared/widgets/main_shell.dart';
import '../../../shared/widgets/section_header.dart';
import '../data/commission_stats.dart';

/// Période choisie (partagée le temps de la session).
final commissionPeriodProvider =
    StateProvider<CommissionPeriod>((ref) => CommissionPeriod.today);

/// Statistiques de la période choisie (invalidé à chaque SMS détecté).
final commissionsStatsProvider = FutureProvider<CommissionStats>((ref) async {
  final period = ref.watch(commissionPeriodProvider);
  return loadCommissionStats(await DatabaseHelper.instance.database, period);
});

/// Commissions : combien j'ai gagné sur la période, avec quels services,
/// chez quel opérateur, et la tendance des deux dernières semaines.
class CommissionsScreen extends ConsumerStatefulWidget {
  const CommissionsScreen({super.key});

  @override
  ConsumerState<CommissionsScreen> createState() => _CommissionsScreenState();
}

class _CommissionsScreenState extends ConsumerState<CommissionsScreen> {
  @override
  void initState() {
    super.initState();
    // Chiffres frais à chaque ouverture.
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.invalidate(commissionsStatsProvider));
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(commissionPeriodProvider);
    final statsAsync = ref.watch(commissionsStatsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Commissions'),
        actions: [
          Consumer(builder: (_, ref, _) {
            final active = ref.watch(smsServiceActiveProvider);
            return Tooltip(
              message: active ? 'Détection des SMS active' : 'Détection des SMS inactive',
              child: Icon(Icons.circle, size: 10, color: active ? Colors.greenAccent : Colors.red),
            );
          }),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Paramètres',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(commissionsStatsProvider),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            SegmentedButton<CommissionPeriod>(
              segments: [
                for (final p in CommissionPeriod.values)
                  ButtonSegment(value: p, label: Text(p.label, maxLines: 1)),
              ],
              selected: {period},
              showSelectedIcon: false,
              onSelectionChanged: (s) => ref.read(commissionPeriodProvider.notifier).state = s.first,
            ),
            const SizedBox(height: 16),
            statsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Erreur : $e'),
              data: (s) => _Content(stats: s, period: period),
            ),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final CommissionStats stats;
  final CommissionPeriod period;

  const _Content({required this.stats, required this.period});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = stats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primaryColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Gagné · ${period.label.toLowerCase()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 6),
              AmountText(AppFormats.fcfa(s.total),
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              Row(children: [
                _Pill('${s.count} opération${s.count > 1 ? 's' : ''}'),
                const SizedBox(width: 8),
                Flexible(child: _Pill('≈ ${AppFormats.fcfa(s.perOperation)} / opération')),
              ]),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader('Ces 14 derniers jours'),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
            child: _DailyBars(values: s.last14Days),
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader('Ce qui vous rapporte'),
        if (s.byService.isEmpty)
          _Empty(period: period)
        else
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                for (final l in s.byService) _RankRow(line: l, max: s.byService.first.commission),
              ]),
            ),
          ),
        const SizedBox(height: 24),
        const SectionHeader('Par opérateur'),
        for (final op in s.byOperator)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(op.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(s.soldes[op.key] == null
                  ? '${op.count} opération${op.count > 1 ? 's' : ''}'
                  : '${op.count} opération${op.count > 1 ? 's' : ''} · float ${AppFormats.fcfa(s.soldes[op.key]!)}'),
              trailing: SizedBox(
                width: 120,
                child: AmountText(AppFormats.fcfa(op.commission),
                    alignment: AlignmentDirectional.centerEnd,
                    style: TextStyle(fontWeight: FontWeight.w800, color: theme.colorScheme.primary)),
              ),
            ),
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withAlpha(30), borderRadius: BorderRadius.circular(20)),
        child: Text(text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// Classement d'un service : barre proportionnelle à la commission.
class _RankRow extends StatelessWidget {
  final CommissionLine line;
  final double max;
  const _RankRow({required this.line, required this.max});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ratio = max <= 0 ? 0.0 : (line.commission / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(line.label,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 120,
              child: AmountText(AppFormats.fcfa(line.commission),
                  alignment: AlignmentDirectional.centerEnd,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 4),
          Text('${line.count} op. · ${AppFormats.fcfa(line.volume)} traités', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Mini-histogramme des commissions par jour (aujourd'hui à droite).
class _DailyBars extends StatelessWidget {
  final List<double> values;
  const _DailyBars({required this.values});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = values.fold<double>(0, (m, v) => v > m ? v : m);
    final now = DateTime.now();
    return Column(
      children: [
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < values.length; i++)
                Expanded(
                  child: Tooltip(
                    message: AppFormats.fcfa(values[i]),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                        height: max <= 0 ? 2 : 2 + 94 * values[i] / max,
                        decoration: BoxDecoration(
                          color: i == values.length - 1
                              ? AppColors.accentColor
                              : AppColors.primaryColor.withAlpha(values[i] > 0 ? 200 : 40),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(children: [
          Text(AppFormats.dayMonth.format(now.subtract(const Duration(days: 13))), style: theme.textTheme.bodySmall),
          const Spacer(),
          Text("Aujourd'hui", style: theme.textTheme.bodySmall),
        ]),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  final CommissionPeriod period;
  const _Empty({required this.period});

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            period == CommissionPeriod.today
                ? 'Pas encore de commission aujourd\'hui. Elles s\'ajoutent toutes seules à chaque SMS d\'opération.'
                : 'Aucune commission sur cette période.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
}
