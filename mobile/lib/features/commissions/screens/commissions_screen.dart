import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/sms/sms_listener.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/main_shell.dart';

/// Provider pour les stats de commissions
final commissionsStatsProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final db = await DatabaseHelper.instance.database;

  // Commissions globales
  final global = await db.rawQuery('''
    SELECT
      COALESCE(SUM(commission), 0) as total_commission,
      COALESCE(SUM(CASE WHEN direction='in' THEN commission ELSE 0 END), 0) as comm_depot,
      COALESCE(SUM(CASE WHEN direction='out' THEN commission ELSE 0 END), 0) as comm_retrait,
      COUNT(*) as tx_count
    FROM transactions
    WHERE status = 'completed' AND commission > 0
  ''');

  // Commissions du jour
  final today = DateTime.now();
  final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  final todayStats = await db.rawQuery('''
    SELECT COALESCE(SUM(commission), 0) as today_commission
    FROM transactions
    WHERE status = 'completed' AND DATE(created_at) = ?
  ''', [todayStr]);

  // Commissions cette semaine
  final weekAgo = today.subtract(const Duration(days: 7));
  final weekStats = await db.rawQuery('''
    SELECT COALESCE(SUM(commission), 0) as week_commission
    FROM transactions
    WHERE status = 'completed' AND created_at >= ?
  ''', [weekAgo.toIso8601String()]);

  // Commissions ce mois
  final monthStart = DateTime(today.year, today.month, 1);
  final monthStats = await db.rawQuery('''
    SELECT COALESCE(SUM(commission), 0) as month_commission
    FROM transactions
    WHERE status = 'completed' AND created_at >= ?
  ''', [monthStart.toIso8601String()]);

  // Par opérateur avec solde (du dernier SMS)
  final perOperator = await db.rawQuery('''
    SELECT
      o.id, o.name, o.sms_sender,
      COALESCE(SUM(t.commission), 0) as total_commission,
      COALESCE(SUM(CASE WHEN t.direction='in' THEN t.commission ELSE 0 END), 0) as comm_depot,
      COALESCE(SUM(CASE WHEN t.direction='out' THEN t.commission ELSE 0 END), 0) as comm_retrait,
      COUNT(t.id) as tx_count
    FROM operators o
    LEFT JOIN transactions t ON t.operator_id = o.id AND t.status = 'completed'
    WHERE o.is_active = 1
    GROUP BY o.id
    ORDER BY total_commission DESC
  ''');

  // Solde par opérateur (depuis le dernier SMS traité)
  final soldes = <String, String>{};
  for (final op in perOperator) {
    final opId = op['id'] as String;
    final lastSms = await db.rawQuery('''
      SELECT sm.body FROM sms_messages sm
      JOIN transactions t ON t.sms_id = sm.id
      WHERE t.operator_id = ? AND t.status = 'completed'
      ORDER BY sm.received_at DESC LIMIT 1
    ''', [opId]);

    if (lastSms.isNotEmpty) {
      final body = lastSms.first['body'] as String;
      // Extraire le solde du SMS
      final soldeMatch = RegExp(
        r'solde(?:\s+de\s+votre\s+compte)?\s+est\s+de\s+(\d[\d,]*(?:\.\d{1,2})?)',
        caseSensitive: false,
      ).firstMatch(body);
      if (soldeMatch != null) {
        soldes[opId] = soldeMatch.group(1)!;
      }
    }
  }

  return {
    'global': global.first,
    'today': (todayStats.first['today_commission'] as num).toDouble(),
    'week': (weekStats.first['week_commission'] as num).toDouble(),
    'month': (monthStats.first['month_commission'] as num).toDouble(),
    'per_operator': perOperator,
    'soldes': soldes,
  };
});

/// Écran Commissions avec filtre opérateur
class CommissionsScreen extends ConsumerStatefulWidget {
  const CommissionsScreen({super.key});

  @override
  ConsumerState<CommissionsScreen> createState() => _CommissionsScreenState();
}

class _CommissionsScreenState extends ConsumerState<CommissionsScreen> {
  String? _selectedOperatorId;

  @override
  void initState() {
    super.initState();
    // Auto-refresh à chaque ouverture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(commissionsStatsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(commissionsStatsProvider);
    final currFmt =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Commissions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(commissionsStatsProvider),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Consumer(builder: (_, ref, _) {
              final active = ref.watch(smsServiceActiveProvider);
              return Tooltip(
                message: active ? 'SMS actif' : 'SMS inactif',
                child: Icon(Icons.circle, size: 10,
                    color: active ? Colors.greenAccent : Colors.red),
              );
            }),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (stats) {
          final global = stats['global'] as Map<String, dynamic>;
          final totalComm = (global['total_commission'] as num).toDouble();
          final commDepot = (global['comm_depot'] as num).toDouble();
          final commRetrait = (global['comm_retrait'] as num).toDouble();
          final todayComm = stats['today'] as double;
          final weekComm = stats['week'] as double;
          final monthComm = stats['month'] as double;
          final perOperator = stats['per_operator'] as List<Map<String, dynamic>>;
          final soldes = stats['soldes'] as Map<String, String>;

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(commissionsStatsProvider),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Carte résumé global
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryColor, AppColors.primaryDark],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Commissions totales',
                          style: TextStyle(color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(currFmt.format(totalComm),
                          style: const TextStyle(color: Colors.white,
                              fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _miniCard('Entrées', currFmt.format(commDepot),
                              AppColors.depositColor),
                          const SizedBox(width: 10),
                          _miniCard('Sorties', currFmt.format(commRetrait),
                              AppColors.withdrawColor),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Périodes
                Row(
                  children: [
                    Expanded(child: _periodCard(context, "Aujourd'hui",
                        currFmt.format(todayComm))),
                    const SizedBox(width: 10),
                    Expanded(child: _periodCard(context, '7 jours',
                        currFmt.format(weekComm))),
                    const SizedBox(width: 10),
                    Expanded(child: _periodCard(context, 'Ce mois',
                        currFmt.format(monthComm))),
                  ],
                ),
                const SizedBox(height: 24),

                // Filtre opérateur
                Text('Par opérateur',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: const Text('Tous', style: TextStyle(fontSize: 12)),
                          selected: _selectedOperatorId == null,
                          onSelected: (_) => setState(() => _selectedOperatorId = null),
                          selectedColor: AppColors.primaryColor.withAlpha(30),
                        ),
                      ),
                      ...perOperator.map((op) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: FilterChip(
                          label: Text(op['name'] as String, style: const TextStyle(fontSize: 12)),
                          selected: _selectedOperatorId == op['id'],
                          onSelected: (_) => setState(() => _selectedOperatorId = op['id'] as String),
                          selectedColor: AppColors.primaryColor.withAlpha(30),
                        ),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                ...perOperator.where((op) =>
                    _selectedOperatorId == null || op['id'] == _selectedOperatorId
                ).map((op) {
                  final opId = op['id'] as String;
                  final name = op['name'] as String;
                  final opComm = (op['total_commission'] as num).toDouble();
                  final opCommDep = (op['comm_depot'] as num).toDouble();
                  final opCommRet = (op['comm_retrait'] as num).toDouble();
                  final txCount = (op['tx_count'] as num).toInt();
                  final soldeRaw = soldes[opId];
                  double? solde;
                  if (soldeRaw != null) {
                    solde = double.tryParse(soldeRaw.replaceAll(',', ''));
                  }

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600, fontSize: 16)),
                              const Spacer(),
                              Text(currFmt.format(opComm),
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Theme.of(context).colorScheme.primary)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text('$txCount transactions',
                                  style: Theme.of(context).textTheme.bodySmall),
                              const Spacer(),
                              Text('Dép: ${currFmt.format(opCommDep)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.depositColor)),
                              const SizedBox(width: 10),
                              Text('Ret: ${currFmt.format(opCommRet)}',
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.withdrawColor)),
                            ],
                          ),
                          if (solde != null) ...[
                            const Divider(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.account_balance_wallet,
                                    size: 16, color: AppColors.primaryColor),
                                const SizedBox(width: 6),
                                const Text('Solde opérateur:',
                                    style: TextStyle(fontSize: 12)),
                                const Spacer(),
                                Text(currFmt.format(solde),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _miniCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(20),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: color, fontSize: 11)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _periodCard(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }
}
