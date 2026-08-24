import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/database/transaction_repository.dart';


final cancelledTransactionsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return TransactionRepository.instance.getCancelled();
});

class CancelledTransactionsScreen extends ConsumerWidget {
  const CancelledTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(cancelledTransactionsProvider);
    final currencyFormat = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions annulées'),
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (transactions) {
          if (transactions.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucune transaction annulée',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final isDeposit = tx['direction'] != null
                  ? tx['direction'] == 'in'
                  : tx['transaction_type'] == 'deposit';
              final typeLabel = (tx['type_label'] as String?) ??
                  (tx['transaction_type'] == 'deposit' ? 'Dépôt' : 'Retrait');
              final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
              final status = tx['status'] as String? ?? '';
              final createdAt = DateTime.parse(tx['created_at'] as String);

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.grey[200],
                    child: Icon(
                      isDeposit
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      color: Colors.grey[600],
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        typeLabel,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        (tx['operator_name'] as String?) ?? '',
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 12),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: status == 'cancelled'
                              ? Colors.orange.shade50
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status == 'cancelled' ? 'Annulée' : 'Rejetée',
                          style: TextStyle(
                            color: status == 'cancelled'
                                ? Colors.orange.shade700
                                : Colors.red.shade700,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        (tx['client_name'] as String?) ??
                            (tx['client_phone'] as String?) ??
                            'Client inconnu',
                        style: TextStyle(
                            color: Colors.grey[600], fontSize: 13),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(createdAt),
                        style: TextStyle(
                            color: Colors.grey[400], fontSize: 11),
                      ),
                    ],
                  ),
                  trailing: Text(
                    currencyFormat.format(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    context.push('/transactions/pending/${tx['id']}').then((_) {
                      ref.invalidate(cancelledTransactionsProvider);
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
