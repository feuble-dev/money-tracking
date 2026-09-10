import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/categories/category_providers.dart';
import '../../../core/categories/category_repository.dart';
import '../../../core/categories/expense_category.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/main_shell.dart';
import '../providers/categorize_provider.dart';

/// 3ᵉ onglet du compte Particulier — budgets mensuels par motif. Remplace
/// l'ancien raccourci « Paramètres » (qui n'était pas un vrai onglet). Chaque
/// ligne : plafond mensuel optionnel + progression face aux dépenses du mois
/// en cours.
class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currency =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);
    final cats = ref.watch(expenseCategoriesProvider);
    final budgets = ref.watch(categoryBudgetsProvider);
    final spend = ref.watch(monthlySpendByCategoryProvider);
    final uncat = ref.watch(uncategorizedCountProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Budget'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Catégories & règles',
            onPressed: () => context.push('/categories/manage'),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: cats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (allCats) {
          final outCats =
              allCats.where((c) => c.matchesDirection('out')).toList();
          final budgetMap = budgets.valueOrNull ?? const {};
          final spendMap = spend.valueOrNull ?? const {};
          final monthLabel = DateFormat.MMMM('fr_FR').format(DateTime.now());

          // Budgétés d'abord, puis le reste.
          outCats.sort((a, b) {
            final ba = budgetMap.containsKey(a.code) ? 0 : 1;
            final bb = budgetMap.containsKey(b.code) ? 0 : 1;
            if (ba != bb) return ba - bb;
            return a.sortOrder.compareTo(b.sortOrder);
          });

          final totalBudget =
              budgetMap.values.fold<double>(0, (s, v) => s + v);
          final totalSpentBudgeted = budgetMap.keys
              .fold<double>(0, (s, k) => s + (spendMap[k] ?? 0));

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (uncat > 0)
                Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: Icon(Icons.label_outline,
                        color: Colors.orange.shade800),
                    title: Text('$uncat dépense${uncat > 1 ? 's' : ''} à catégoriser'),
                    subtitle: const Text('Les budgets ignorent les dépenses sans motif'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/categorize'),
                  ),
                ),
              if (totalBudget > 0) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryDark,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Budget de $monthLabel',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(
                        '${currency.format(totalSpentBudgeted)} / ${currency.format(totalBudget)}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalBudget > 0
                              ? (totalSpentBudgeted / totalBudget).clamp(0, 1)
                              : 0,
                          minHeight: 7,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation(
                            totalSpentBudgeted > totalBudget
                                ? Colors.redAccent
                                : Colors.greenAccent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text('Dépenses de $monthLabel par motif',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ...outCats.map((c) => _BudgetRow(
                    category: c,
                    limit: budgetMap[c.code],
                    spent: spendMap[c.code] ?? 0,
                    currency: currency,
                    onEdit: () => _editBudget(context, ref, c, budgetMap[c.code]),
                  )),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  Future<void> _editBudget(BuildContext context, WidgetRef ref,
      ExpenseCategory cat, double? current) async {
    final ctrl = TextEditingController(
        text: current != null && current > 0 ? current.toStringAsFixed(0) : '');
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Budget — ${cat.label}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Plafond mensuel (FCFA)',
            hintText: 'Laisser vide pour retirer',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, -1.0),
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final v = double.tryParse(
                      ctrl.text.replaceAll(RegExp(r'[^\d]'), '')) ??
                  0;
              Navigator.pop(ctx, v);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (value == null || value < 0) return;
    await CategoryRepository.setBudget(cat.code, value);
    ref.invalidate(categoryBudgetsProvider);
  }
}

class _BudgetRow extends StatelessWidget {
  final ExpenseCategory category;
  final double? limit;
  final double spent;
  final NumberFormat currency;
  final VoidCallback onEdit;

  const _BudgetRow({
    required this.category,
    required this.limit,
    required this.spent,
    required this.currency,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final hasBudget = limit != null && limit! > 0;
    final ratio = hasBudget ? (spent / limit!).clamp(0.0, 1.0) : 0.0;
    final over = hasBudget && spent > limit!;
    final near = hasBudget && !over && spent >= limit! * 0.8;

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            Row(
              children: [
                Text(category.icon, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(category.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                ),
                if (over)
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Colors.red),
                if (near)
                  Icon(Icons.info_outline,
                      size: 16, color: Colors.orange.shade700),
                const SizedBox(width: 6),
                Text(
                  hasBudget
                      ? '${currency.format(spent)} / ${currency.format(limit!)}'
                      : currency.format(spent),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: over ? Colors.red : null,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(hasBudget ? Icons.edit : Icons.add,
                    size: 15, color: Colors.grey[500]),
              ],
            ),
            if (hasBudget) ...[
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: ratio,
                  minHeight: 5,
                  backgroundColor: Colors.grey.withAlpha(30),
                  valueColor: AlwaysStoppedAnimation(
                    over
                        ? Colors.red
                        : near
                            ? Colors.orange
                            : category.color,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
