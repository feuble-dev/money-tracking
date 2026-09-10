import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/categories/category_providers.dart';
import '../../../core/categories/expense_category.dart';

/// Résultat d'un choix de catégorie.
class CategoryChoice {
  final String code;

  /// L'utilisateur a coché « toujours ranger ici » — le caller crée alors
  /// une règle d'auto-catégorisation.
  final bool remember;

  const CategoryChoice(this.code, {this.remember = false});
}

/// Feuille de sélection d'un motif — grille d'icônes + libellés, grands
/// boutons tactiles. Option « toujours ranger [cible] ici » quand
/// [rememberTarget] est fourni (ex: le nom ou le numéro du bénéficiaire).
Future<CategoryChoice?> showCategoryPicker(
  BuildContext context, {
  required String direction, // 'in' | 'out'
  String? current,
  String? rememberTarget,
}) {
  return showModalBottomSheet<CategoryChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _CategoryPickerSheet(
      direction: direction,
      current: current,
      rememberTarget: rememberTarget,
    ),
  );
}

class _CategoryPickerSheet extends ConsumerStatefulWidget {
  final String direction;
  final String? current;
  final String? rememberTarget;

  const _CategoryPickerSheet({
    required this.direction,
    this.current,
    this.rememberTarget,
  });

  @override
  ConsumerState<_CategoryPickerSheet> createState() => _CategoryPickerSheetState();
}

class _CategoryPickerSheetState extends ConsumerState<_CategoryPickerSheet> {
  bool _remember = false;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return categoriesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
          data: (all) {
            final cats = all
                .where((c) => c.matchesDirection(widget.direction))
                .toList();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      Text(
                        widget.direction == 'in'
                            ? 'Origine de ce revenu'
                            : 'Motif de cette dépense',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CategoryGrid(
                    categories: cats,
                    current: widget.current,
                    scrollController: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    onSelected: (code) => Navigator.pop(
                      context,
                      CategoryChoice(code, remember: _remember),
                    ),
                  ),
                ),
                if (widget.rememberTarget != null)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                      child: CheckboxListTile(
                        dense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        value: _remember,
                        onChanged: (v) =>
                            setState(() => _remember = v ?? false),
                        title: Text(
                          'Toujours ranger « ${widget.rememberTarget} » dans ce motif',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Grille réutilisable de tuiles catégorie (feuille de sélection + écran de
/// catégorisation rapide).
class CategoryGrid extends StatelessWidget {
  final List<ExpenseCategory> categories;
  final String? current;
  final ValueChanged<String> onSelected;
  final ScrollController? scrollController;
  final EdgeInsets padding;
  final bool shrinkWrap;

  const CategoryGrid({
    super.key,
    required this.categories,
    required this.onSelected,
    this.current,
    this.scrollController,
    this.padding = const EdgeInsets.all(16),
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      controller: scrollController,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.95,
      ),
      itemCount: categories.length,
      itemBuilder: (context, i) {
        final c = categories[i];
        return _CategoryTile(
          category: c,
          selected: c.code == current,
          onTap: () => onSelected(c.code),
        );
      },
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final ExpenseCategory category;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = category.color;
    return Material(
      color: selected ? color.withAlpha(40) : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? color : Colors.grey.withAlpha(50),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(category.icon, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 6),
              Text(
                category.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, height: 1.1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
