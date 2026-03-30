import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/transaction_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';

/// Provider pour les transactions récentes (pending + completed)
final recentActivityProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  return db.rawQuery('''
    SELECT t.*, o.name as operator_name,
           CASE WHEN t.client_id IS NULL AND t.client_phone != '' THEN 1 ELSE 0 END as needs_client
    FROM transactions t
    LEFT JOIN operators o ON t.operator_id = o.id
    WHERE t.source = 'sms_auto' AND t.status != 'rejected'
    ORDER BY t.created_at DESC
    LIMIT 50
  ''');
});

/// Écran notifications / activité récente
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(recentActivityProvider);
    final dateFormat = DateFormat('dd/MM HH:mm', 'fr_FR');
    final currencyFormat =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(recentActivityProvider),
          ),
        ],
      ),
      body: activityAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (activities) {
          if (activities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Aucune activité',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text(
                    'Les transactions détectées par SMS\napparaîtront ici.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: activities.length,
            itemBuilder: (context, index) {
              final tx = activities[index];
              final isDeposit = tx['transaction_type'] == 'deposit';
              final color = isDeposit ? AppColors.depositColor : AppColors.withdrawColor;
              final typeLabel = isDeposit ? 'Dépôt' : 'Retrait';
              final amount = (tx['amount'] as num).toDouble();
              final clientName = tx['client_name'] as String?;
              final clientPhone = tx['client_phone'] as String? ?? '';
              final operatorName = tx['operator_name'] as String? ?? '';
              final needsClient = (tx['needs_client'] as int?) == 1;
              final createdAt = DateTime.parse(tx['created_at'] as String);
              final txId = tx['id'] as String;
              final status = tx['status'] as String? ?? 'pending';
              final isPending = status == 'pending';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      // En-tête transaction
                      Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: color.withAlpha(20),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                              color: color, size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('$typeLabel — $operatorName',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: color, fontSize: 13)),
                                    const Spacer(),
                                    Text(currencyFormat.format(amount),
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: color, fontSize: 14)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(clientName ?? clientPhone,
                                    style: const TextStyle(fontSize: 13)),
                                Text(dateFormat.format(createdAt),
                                    style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Boutons d'action
                      if (isPending)
                        Row(
                          children: [
                            // Badge en attente
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('En attente',
                                  style: TextStyle(fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange)),
                            ),
                            const Spacer(),
                            // Bouton Rejeter
                            TextButton.icon(
                              onPressed: () => _rejectTx(context, ref, txId),
                              icon: const Icon(Icons.close, size: 16, color: Colors.red),
                              label: const Text('Rejeter',
                                  style: TextStyle(color: Colors.red, fontSize: 12)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Bouton Confirmer
                            ElevatedButton.icon(
                              onPressed: () => _confirmTx(context, ref, txId),
                              icon: const Icon(Icons.check, size: 16),
                              label: const Text('Confirmer', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.withdrawColor,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            // Badge confirmé
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.withdrawColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, size: 14, color: AppColors.withdrawColor),
                                  SizedBox(width: 4),
                                  Text('Confirmé',
                                      style: TextStyle(fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.withdrawColor)),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Client inconnu → créer
                            if (needsClient)
                              TextButton.icon(
                                onPressed: () => context.push('/clients/add'),
                                icon: const Icon(Icons.person_add, size: 14,
                                    color: AppColors.accentColor),
                                label: const Text('Créer client',
                                    style: TextStyle(fontSize: 11,
                                        color: AppColors.accentColor)),
                              ),
                            // Annuler une transaction confirmée
                            TextButton.icon(
                              onPressed: () => _cancelTx(context, ref, txId),
                              icon: const Icon(Icons.undo, size: 14, color: Colors.grey),
                              label: const Text('Annuler',
                                  style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmTx(BuildContext context, WidgetRef ref, String txId) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('transactions', {'status': 'completed'},
        where: 'id = ?', whereArgs: [txId]);
    ref.invalidate(recentActivityProvider);
    ref.read(transactionsProvider.notifier).loadTransactions();
    ref.invalidate(dashboardStatsProvider(null));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction confirmée'),
            backgroundColor: AppColors.withdrawColor),
      );
    }
  }

  void _rejectTx(BuildContext context, WidgetRef ref, String txId) async {
    await TransactionRepository.instance.reject(txId);
    ref.invalidate(recentActivityProvider);
    ref.read(transactionsProvider.notifier).loadTransactions();
    ref.read(pendingTransactionsProvider.notifier).loadPending();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction rejetée')),
      );
    }
  }

  void _cancelTx(BuildContext context, WidgetRef ref, String txId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler cette transaction ?'),
        content: const Text('La transaction sera marquée comme annulée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, annuler'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await TransactionRepository.instance.reject(txId);
      ref.invalidate(recentActivityProvider);
      ref.read(transactionsProvider.notifier).loadTransactions();
      ref.invalidate(dashboardStatsProvider(null));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction annulée')),
        );
      }
    }
  }
}
