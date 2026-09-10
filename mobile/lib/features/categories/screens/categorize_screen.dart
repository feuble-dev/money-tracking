import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/categories/category_providers.dart';
import '../../../core/categories/category_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../transactions/models/transaction_model.dart';
import '../../transactions/providers/transaction_provider.dart';
import '../providers/categorize_provider.dart';
import '../providers/recurring_provider.dart';
import '../widgets/category_picker_sheet.dart';

/// Catégorisation rapide des dépenses — une transaction à la fois, grande
/// grille de motifs. Alimentée par la file des dépenses non catégorisées ;
/// si [startId] est fourni (tap notification / détail transaction), cette
/// transaction est traitée en premier puis on enchaîne sur la file.
class CategorizeScreen extends ConsumerStatefulWidget {
  final String? startId;

  const CategorizeScreen({super.key, this.startId});

  @override
  ConsumerState<CategorizeScreen> createState() => _CategorizeScreenState();
}

class _CategorizeScreenState extends ConsumerState<CategorizeScreen> {
  final _currency =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

  List<TransactionModel>? _queue;
  int _index = 0;
  int _done = 0;

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    final list = [...await ref.read(uncategorizedTransactionsProvider.future)];
    if (widget.startId != null) {
      final i = list.indexWhere((t) => t.id == widget.startId);
      if (i > 0) {
        final t = list.removeAt(i);
        list.insert(0, t);
      } else if (i < 0) {
        final single =
            await ref.read(singleTransactionProvider(widget.startId!).future);
        if (single != null && single.isUncategorized) list.insert(0, single);
      }
    }
    if (mounted) setState(() => _queue = list);
  }

  TransactionModel? get _current =>
      (_queue != null && _index < _queue!.length) ? _queue![_index] : null;

  Future<void> _assign(String code, {bool remember = false}) async {
    final tx = _current;
    if (tx == null) return;
    ({String matchType, String matchValue})? rule;
    if (remember) {
      if ((tx.clientName ?? '').trim().isNotEmpty) {
        rule = (matchType: 'name', matchValue: tx.clientName!.trim());
      } else if (tx.clientPhone.trim().isNotEmpty) {
        rule = (matchType: 'phone', matchValue: tx.clientPhone.trim());
      }
    }
    await CategoryRepository.setTransactionCategory(tx.id,
        category: code, rememberFor: rule);
    _refreshProviders();
    setState(() {
      _index++;
      _done++;
    });
  }

  void _skip() => setState(() => _index++);

  void _refreshProviders() {
    invalidateCategoryProviders(ref);
    ref.invalidate(uncategorizedTransactionsProvider);
    ref.invalidate(recurringPaymentsProvider);
    ref.read(transactionsProvider.notifier).loadTransactions();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);
    final queue = _queue;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catégoriser'),
        bottom: queue == null || queue.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(4),
                child: LinearProgressIndicator(
                  value: queue.isEmpty ? 1 : (_done / queue.length),
                  minHeight: 4,
                ),
              ),
      ),
      body: queue == null
          ? const Center(child: CircularProgressIndicator())
          : _current == null
              ? _buildDone(context)
              : categoriesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erreur: $e')),
                  data: (all) {
                    final cats = all
                        .where((c) => c.matchesDirection('out'))
                        .toList();
                    return Column(
                      children: [
                        _buildTxCard(_current!),
                        Expanded(
                          child: CategoryGrid(
                            categories: cats,
                            current: _current!.category,
                            onSelected: (code) => _assign(code),
                          ),
                        ),
                        SafeArea(
                          top: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                            child: Row(
                              children: [
                                Text('${_index + 1} / ${queue.length}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall),
                                const Spacer(),
                                TextButton.icon(
                                  onPressed: _skip,
                                  icon: const Icon(Icons.skip_next, size: 18),
                                  label: const Text('Passer'),
                                ),
                                const SizedBox(width: 4),
                                OutlinedButton(
                                  onPressed: () => _assignViaSheet(_current!),
                                  child: const Text('Plus…'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  Future<void> _assignViaSheet(TransactionModel tx) async {
    final target = (tx.clientName ?? '').trim().isNotEmpty
        ? tx.clientName!.trim()
        : (tx.clientPhone.trim().isNotEmpty ? tx.clientPhone.trim() : null);
    final choice = await showCategoryPicker(
      context,
      direction: 'out',
      current: tx.category,
      rememberTarget: target,
    );
    if (choice != null) _assign(choice.code, remember: choice.remember);
  }

  Widget _buildTxCard(TransactionModel tx) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.withdrawColor.withAlpha(15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.withdrawColor.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _currency.format(tx.amount),
            style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColors.withdrawColor),
          ),
          const SizedBox(height: 4),
          Text(
            '${tx.displayLabel} · ${tx.operatorName ?? ''}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if ((tx.clientName ?? '').isNotEmpty || tx.clientPhone.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                tx.clientName?.isNotEmpty == true
                    ? '${tx.clientName} (${tx.clientPhone})'
                    : tx.clientPhone,
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ),
          Text(_dateFormat.format(tx.createdAt),
              style: TextStyle(fontSize: 12, color: Colors.grey[600])),
          _RecurringHint(
            label: (tx.clientName ?? '').trim().isNotEmpty
                ? tx.clientName!.trim()
                : tx.clientPhone.trim(),
            onApply: (code) => _assign(code, remember: true),
          ),
        ],
      ),
    );
  }

  Widget _buildDone(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline,
                size: 72, color: AppColors.accentColor),
            const SizedBox(height: 16),
            Text(
              _done > 0
                  ? '$_done dépense${_done > 1 ? 's' : ''} catégorisée${_done > 1 ? 's' : ''} 👍'
                  : 'Tout est déjà catégorisé 🎉',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go('/dashboard'),
              child: const Text('Terminer'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Encart « paiement récurrent » sur l'écran de catégorisation : si le
/// bénéficiaire a une série récurrente avec un motif dominant, propose de
/// l'appliquer en un tap (et de créer la règle).
class _RecurringHint extends ConsumerWidget {
  final String label;
  final ValueChanged<String> onApply;

  const _RecurringHint({required this.label, required this.onApply});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (label.isEmpty) return const SizedBox.shrink();
    final series =
        ref.watch(recurringForBeneficiaryProvider(label)).valueOrNull;
    if (series == null) return const SizedBox.shrink();
    final catMap = ref.watch(categoriesByCodeProvider).valueOrNull ?? {};
    final cat = series.dominantCategory != null
        ? catMap[series.dominantCategory]
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(Icons.autorenew, size: 15, color: AppColors.primaryColor),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              cat != null
                  ? 'Paiement récurrent — d\'habitude : ${cat.label}'
                  : 'Paiement récurrent (${series.count}×)',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.primaryColor),
            ),
          ),
          if (cat != null)
            TextButton(
              onPressed: () => onApply(cat.code),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Appliquer'),
            ),
        ],
      ),
    );
  }
}
