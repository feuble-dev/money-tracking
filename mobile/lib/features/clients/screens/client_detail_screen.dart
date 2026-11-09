import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/format/formats.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../transactions/models/transaction_model.dart';
import '../providers/client_provider.dart';

/// Historique d'un client — provider plutôt qu'un FutureBuilder recréé à
/// chaque reconstruction (la requête repartait à chaque rafraîchissement).
final clientTransactionsProvider =
    FutureProvider.family<List<TransactionModel>, String>((ref, clientId) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.rawQuery('''
    SELECT t.*, o.name as operator_name, tt.label as type_label
    FROM transactions t
    LEFT JOIN operators o ON t.operator_id = o.id
    LEFT JOIN transaction_types tt ON t.transaction_type_id = tt.id
    WHERE t.client_id = ?
    ORDER BY t.created_at DESC
  ''', [clientId]);
  return rows.map(TransactionModel.fromMap).toList();
});

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
                icon: const Icon(Icons.call_outlined),
                tooltip: 'Appeler',
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: client.phoneNumber)),
              ),
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
                        client.initials,
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

              Expanded(
                child: ref.watch(clientTransactionsProvider(clientId)).when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erreur : $e')),
                  data: (transactions) => _History(
                    transactions: transactions,
                    dateFormat: dateFormat,
                    currencyFormat: currencyFormat,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _History extends StatelessWidget {
  final List<TransactionModel> transactions;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;

  const _History({
    required this.transactions,
    required this.dateFormat,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = transactions.where((t) => t.status == 'completed').toList();
    final volume = done.fold<double>(0, (s, t) => s + t.amount);
    final commissions = done.fold<double>(0, (s, t) => s + t.commission);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Row(children: [
          _Stat(label: 'Opérations', value: '${done.length}'),
          _Stat(label: 'Volume', value: AppFormats.fcfa(volume)),
          _Stat(label: 'Commissions', value: AppFormats.fcfa(commissions)),
        ]),
        if (done.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text('Dernière visite : ${dateFormat.format(done.first.createdAt)}',
                style: theme.textTheme.bodySmall),
          ),
        const SizedBox(height: 16),
        Row(children: [
          const Icon(Icons.history, size: 20),
          const SizedBox(width: 8),
          Text('Historique', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: Text('Aucune transaction pour ce client')),
          ),
        for (final tx in transactions) _row(context, tx),
      ],
    );
  }

  Widget _row(BuildContext context, TransactionModel tx) {
    final cancelled = tx.status == 'cancelled';
    final color = cancelled
        ? Colors.grey
        : tx.isEntrant
            ? AppColors.depositColor
            : AppColors.withdrawColor;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(tx.isEntrant ? Icons.arrow_downward : Icons.arrow_upward, color: color),
      title: Text(
        '${tx.displayLabel} - ${currencyFormat.format(tx.amount)}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: color,
          decoration: cancelled ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text([
        tx.operatorName ?? '',
        dateFormat.format(tx.createdAt),
        if (cancelled) 'annulée',
        if (tx.status == 'pending') 'à vérifier',
      ].where((s) => s.isNotEmpty).join(' · ')),
      trailing: tx.operatorTransactionId == null
          ? null
          : Text(tx.operatorTransactionId!, style: const TextStyle(fontSize: 11)),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            AmountText(value,
                alignment: Alignment.center,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ]),
        ),
      );
}
