import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../providers/transaction_provider.dart';

/// Écran liste des transactions en attente de confirmation
class PendingListScreen extends ConsumerWidget {
  const PendingListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingTransactionsProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
    final currencyFormat =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('En attente de confirmation'),
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune transaction en attente',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Les SMS détectés apparaîtront ici',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            cacheExtent: 500,
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final isDeposit = tx.isDeposit;
              final color = isDeposit
                  ? AppColors.depositColor
                  : AppColors.withdrawColor;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      context.push('/transactions/pending/${tx.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Icône avec badge "en attente"
                        Stack(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.accentColor.withAlpha(25),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                isDeposit
                                    ? Icons.arrow_downward
                                    : Icons.arrow_upward,
                                color: color,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: const BoxDecoration(
                                  color: AppColors.accentColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Infos
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${isDeposit ? "Dépôt" : "Retrait"} — En attente',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.accentColor,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(tx.clientPhone,
                                  style: const TextStyle(fontSize: 13)),
                              Text(
                                '${tx.operatorName ?? ""} — ${dateFormat.format(tx.createdAt)}',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        // Montant
                        Text(
                          currencyFormat.format(tx.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
