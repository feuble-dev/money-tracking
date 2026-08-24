import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_colors.dart';
import '../../transactions/models/transaction_model.dart';
import '../providers/client_provider.dart';

/// Écran détail d'un client avec historique transactions
class ClientDetailScreen extends ConsumerWidget {
  final String clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(clientsProvider);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
    final currencyFormat =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return clientsAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Erreur: $e'))),
      data: (clients) {
        final client =
            clients.where((c) => c.id == clientId).firstOrNull;
        if (client == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('Client introuvable')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(client.fullName),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () =>
                    context.push('/clients/edit/${client.id}'),
              ),
            ],
          ),
          body: Column(
            children: [
              // Infos client
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryColor.withAlpha(30),
                      child: Text(
                        '${client.firstName[0]}${client.lastName[0]}'
                            .toUpperCase(),
                        style: const TextStyle(
                          fontSize: 24,
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      client.fullName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(client.phoneNumber,
                        style: TextStyle(color: Colors.grey[600])),
                    if (client.cnibNumber != null) ...[
                      const SizedBox(height: 4),
                      Text('CNIB: ${client.cnibNumber}',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13)),
                    ],
                    if (client.birthDate != null) ...[
                      const SizedBox(height: 4),
                      Text('Né(e) le ${client.birthDate}',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13)),
                    ],
                  ],
                ),
              ),

              // Titre historique
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.history, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Historique des transactions',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),

              // Liste transactions
              Expanded(
                child: FutureBuilder<List<TransactionModel>>(
                  future: _getClientTransactions(clientId),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final transactions = snapshot.data!;
                    if (transactions.isEmpty) {
                      return const Center(
                        child: Text('Aucune transaction pour ce client'),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: transactions.length,
                      itemBuilder: (context, index) {
                        final tx = transactions[index];
                        final isDeposit = tx.isEntrant;
                        return ListTile(
                          leading: Icon(
                            isDeposit
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: isDeposit
                                ? AppColors.depositColor
                                : AppColors.withdrawColor,
                          ),
                          title: Text(
                            '${tx.displayLabel} - ${currencyFormat.format(tx.amount)}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isDeposit
                                  ? AppColors.depositColor
                                  : AppColors.withdrawColor,
                            ),
                          ),
                          subtitle: Text(
                            '${tx.operatorName ?? ''} - ${dateFormat.format(tx.createdAt)}',
                          ),
                          trailing: tx.operatorTransactionId != null
                              ? Text(
                                  tx.operatorTransactionId!,
                                  style: const TextStyle(fontSize: 11),
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<TransactionModel>> _getClientTransactions(
      String clientId) async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.rawQuery('''
      SELECT t.*, o.name as operator_name, tt.label as type_label
      FROM transactions t
      LEFT JOIN operators o ON t.operator_id = o.id
      LEFT JOIN transaction_types tt ON t.transaction_type_id = tt.id
      WHERE t.client_id = ?
      ORDER BY t.created_at DESC
    ''', [clientId]);
    return results.map((e) => TransactionModel.fromMap(e)).toList();
  }
}
