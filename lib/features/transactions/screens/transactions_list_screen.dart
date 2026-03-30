import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/main_shell.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../../operators/providers/operator_provider.dart';

/// Écran historique des transactions avec filtres opérateurs en chips
class TransactionsListScreen extends ConsumerStatefulWidget {
  const TransactionsListScreen({super.key});

  @override
  ConsumerState<TransactionsListScreen> createState() =>
      _TransactionsListScreenState();
}

class _TransactionsListScreenState
    extends ConsumerState<TransactionsListScreen> {
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
  final _currencyFormat =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsProvider);
    final filter = ref.watch(transactionFilterProvider);
    final pendingCount = ref.watch(pendingCountProvider);
    final operatorsAsync = ref.watch(operatorsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Transactions'),
        actions: [
          if (pendingCount > 0)
            IconButton(
              onPressed: () => context.push('/notifications'),
              icon: Badge(
                label: Text(pendingCount.toString()),
                backgroundColor: AppColors.accentColor,
                child: const Icon(Icons.notification_important),
              ),
              tooltip: '$pendingCount en attente',
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showFilterSheet(context, ref, filter),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par numéro ou nom...',
                hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary.withAlpha(180)),
                prefixIcon: Icon(Icons.search,
                    color: Theme.of(context).colorScheme.onPrimary.withAlpha(200)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.close,
                            color: Theme.of(context).colorScheme.onPrimary, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(transactionFilterProvider.notifier).state =
                              filter.copyWith(searchQuery: null);
                          ref.read(transactionsProvider.notifier).loadTransactions();
                        },
                      )
                    : null,
                filled: true,
                fillColor: Theme.of(context).colorScheme.onPrimary.withAlpha(30),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              onChanged: (query) {
                ref.read(transactionFilterProvider.notifier).state =
                    filter.copyWith(searchQuery: query.isEmpty ? null : query);
                ref.read(transactionsProvider.notifier).loadTransactions();
              },
            ),
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'withdraw',
            onPressed: () => context.push('/transactions/new/withdrawal'),
            backgroundColor: AppColors.withdrawColor,
            child: const Icon(Icons.arrow_upward),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'deposit',
            onPressed: () => context.push('/transactions/new/deposit'),
            backgroundColor: AppColors.depositColor,
            child: const Icon(Icons.arrow_downward),
          ),
        ],
      ),
      body: Column(
        children: [
          // Chips filtres opérateurs en haut
          operatorsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (operators) {
              final activeOps = operators.where((o) => o.isActive).toList();
              if (activeOps.isEmpty) return const SizedBox.shrink();

              return Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 6),
                      child: ChoiceChip(
                        label: const Text('Tous', style: TextStyle(fontSize: 12)),
                        selected: filter.operatorId == null,
                        onSelected: (_) {
                          _updateFilter(
                              ref, filter.copyWith(operatorId: null));
                        },
                      ),
                    ),
                    ...activeOps.map((op) => Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 6),
                          child: ChoiceChip(
                            label:
                                Text(op.name, style: const TextStyle(fontSize: 12)),
                            selected: filter.operatorId == op.id,
                            onSelected: (_) {
                              _updateFilter(
                                  ref, filter.copyWith(operatorId: op.id));
                            },
                          ),
                        )),
                  ],
                ),
              );
            },
          ),

          // Chips filtres actifs (type, date)
          _buildActiveFilters(filter),

          // Liste
          Expanded(
            child: transactionsAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucune transaction',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                double totalDep = 0, totalWit = 0;
                for (final tx in transactions) {
                  if (tx.isDeposit) {
                    totalDep += tx.amount;
                  } else {
                    totalWit += tx.amount;
                  }
                }

                return Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Text('${transactions.length} transactions',
                              style: Theme.of(context).textTheme.bodySmall),
                          const Spacer(),
                          Text('+${_currencyFormat.format(totalDep)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.depositColor,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          Text('-${_currencyFormat.format(totalWit)}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.withdrawColor,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        cacheExtent: 800,
                        addAutomaticKeepAlives: true,
                        itemCount: transactions.length,
                        itemBuilder: (context, index) => RepaintBoundary(
                          child: _TransactionCard(
                            transaction: transactions[index],
                            dateFormat: _dateFormat,
                            currencyFormat: _currencyFormat,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilters(TransactionFilter filter) {
    final hasFilter = filter.transactionType != null ||
        filter.dateFrom != null;

    if (!hasFilter) return const SizedBox.shrink();

    return Container(
      height: 46,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          if (filter.transactionType != null)
            _filterChip(
              filter.transactionType == 'deposit' ? 'Dépôts' : 'Retraits',
              filter.transactionType == 'deposit'
                  ? AppColors.depositColor
                  : AppColors.withdrawColor,
              () => _updateFilter(ref, filter.copyWith(transactionType: null)),
            ),
          if (filter.dateFrom != null)
            _filterChip(
              '${DateFormat('dd/MM').format(filter.dateFrom!)} → ${filter.dateTo != null ? DateFormat('dd/MM').format(filter.dateTo!) : 'Aujourd\'hui'}',
              AppColors.primaryDark,
              () => _updateFilter(
                  ref, filter.copyWith(dateFrom: null, dateTo: null)),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: ActionChip(
              label: const Text('Tout effacer', style: TextStyle(fontSize: 12)),
              onPressed: () {
                ref.read(transactionFilterProvider.notifier).state =
                    const TransactionFilter();
                ref.read(transactionsProvider.notifier).loadTransactions();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, Color color, VoidCallback onRemove) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Chip(
        label: Text(label,
            style: TextStyle(fontSize: 12, color: color)),
        deleteIcon: Icon(Icons.close, size: 14, color: color),
        onDeleted: onRemove,
        backgroundColor: color.withAlpha(20),
        side: BorderSide.none,
      ),
    );
  }

  void _updateFilter(WidgetRef ref, TransactionFilter filter) {
    ref.read(transactionFilterProvider.notifier).state = filter;
    ref.read(transactionsProvider.notifier).loadTransactions();
  }

  void _showFilterSheet(
      BuildContext context, WidgetRef ref, TransactionFilter currentFilter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.7,
          expand: false,
          builder: (context, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Filtrer les transactions',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        )),
                const SizedBox(height: 20),

                // Type
                const Text('Type',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _typeChip(ref, currentFilter, null, 'Tous',
                        Icons.swap_vert, AppColors.primaryColor),
                    _typeChip(ref, currentFilter, 'deposit', 'Dépôts',
                        Icons.arrow_downward, AppColors.depositColor),
                    _typeChip(ref, currentFilter, 'withdrawal', 'Retraits',
                        Icons.arrow_upward, AppColors.withdrawColor),
                  ],
                ),
                const SizedBox(height: 20),

                // Période
                const Text('Période',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _periodChip(ref, currentFilter, null, null, 'Tout'),
                    _periodChip(ref, currentFilter, 0, 0, 'Aujourd\'hui'),
                    _periodChip(ref, currentFilter, 1, 1, 'Hier'),
                    _periodChip(ref, currentFilter, 6, 0, '7 jours'),
                    _periodChip(ref, currentFilter, 29, 0, '30 jours'),
                    _periodChip(ref, currentFilter, 89, 0, '3 mois'),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _pickDateRange(context, ref, currentFilter),
                  icon: const Icon(Icons.date_range, size: 18),
                  label: const Text('Période personnalisée'),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        );
      },
    );
  }

  Widget _typeChip(WidgetRef ref, TransactionFilter filter, String? type,
      String label, IconData icon, Color color) {
    final isSelected = filter.transactionType == type;
    return ChoiceChip(
      avatar: Icon(icon, size: 18, color: isSelected ? Colors.white : color),
      label: Text(label),
      selected: isSelected,
      selectedColor: color,
      onSelected: (_) {
        _applyFilter(ref, TransactionFilter(
          operatorId: filter.operatorId,
          clientId: filter.clientId,
          transactionType: type,
          dateFrom: filter.dateFrom,
          dateTo: filter.dateTo,
        ));
        Navigator.pop(context);
      },
    );
  }

  Widget _periodChip(WidgetRef ref, TransactionFilter filter,
      int? daysBack, int? daysEnd, String label) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () {
        final now = DateTime.now();
        DateTime? from;
        DateTime? to;
        if (daysBack != null) {
          from = DateTime(now.year, now.month, now.day - daysBack);
          to = DateTime(now.year, now.month, now.day - (daysEnd ?? 0), 23, 59, 59);
        }
        _applyFilter(ref, TransactionFilter(
          operatorId: filter.operatorId,
          clientId: filter.clientId,
          transactionType: filter.transactionType,
          dateFrom: from,
          dateTo: to,
        ));
        Navigator.pop(context);
      },
    );
  }

  Future<void> _pickDateRange(
      BuildContext context, WidgetRef ref, TransactionFilter filter) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );
    if (range != null) {
      _applyFilter(ref, TransactionFilter(
        operatorId: filter.operatorId,
        clientId: filter.clientId,
        transactionType: filter.transactionType,
        dateFrom: range.start,
        dateTo: DateTime(
            range.end.year, range.end.month, range.end.day, 23, 59, 59),
      ));
      if (context.mounted) Navigator.pop(context);
    }
  }

  void _applyFilter(WidgetRef ref, TransactionFilter filter) {
    ref.read(transactionFilterProvider.notifier).state = filter;
    ref.read(transactionsProvider.notifier).loadTransactions();
  }
}

// === Transaction Card ===

class _TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final DateFormat dateFormat;
  final NumberFormat currencyFormat;

  const _TransactionCard({
    required this.transaction,
    required this.dateFormat,
    required this.currencyFormat,
  });

  @override
  Widget build(BuildContext context) {
    final isDeposit = transaction.isDeposit;
    final color = isDeposit ? AppColors.depositColor : AppColors.withdrawColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isDeposit ? 'Dépôt' : 'Retrait',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, color: color),
                        ),
                        if (transaction.source == 'sms_auto') ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.accentColor.withAlpha(30),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text('SMS',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.accentColor,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.clientName ?? transaction.clientPhone,
                      style: const TextStyle(fontSize: 13),
                    ),
                    Text(
                      '${transaction.operatorName ?? ''} — ${dateFormat.format(transaction.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isDeposit ? '+' : '-'}${currencyFormat.format(transaction.amount)}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: color, fontSize: 15),
                  ),
                  if (transaction.commission > 0)
                    Text(
                      'Com: ${currencyFormat.format(transaction.commission)}',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey[600]),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (ctx2, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Poignée
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    '${transaction.isDeposit ? 'Dépôt' : 'Retrait'} — ${currencyFormat.format(transaction.amount)}',
                    style: Theme.of(ctx2).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _buildRow('Client', transaction.clientName ?? '-'),
                  _buildRow('Téléphone', transaction.clientPhone),
                  _buildRow('Opérateur', transaction.operatorName ?? '-'),
                  _buildRow('Date', dateFormat.format(transaction.createdAt)),
                  _buildRow('Source',
                      transaction.source == 'sms_auto' ? 'SMS Auto' : 'Manuel'),
                  if (transaction.commission > 0)
                    _buildRow('Commission',
                        currencyFormat.format(transaction.commission)),
                  if (transaction.clientCnib != null)
                    _buildRow('CNIB', transaction.clientCnib!),
                  if (transaction.clientBirthDate != null)
                    _buildRow('Date naiss.', transaction.clientBirthDate!),
                  if (transaction.operatorTransactionId != null)
                    _buildRow('ID Transaction',
                        transaction.operatorTransactionId!),
                  if (transaction.operatorReference != null)
                    _buildRow('Référence', transaction.operatorReference!),
                  if (transaction.smsRaw != null) ...[
                    const SizedBox(height: 12),
                    const Text('SMS brut :',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(ctx2).colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(transaction.smsRaw!,
                          style: const TextStyle(
                              fontFamily: 'monospace', fontSize: 12)),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500, color: Colors.grey)),
          ),
          Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
