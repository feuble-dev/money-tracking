import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/categories/category_providers.dart';
import '../../../core/categories/category_repository.dart';
import '../../../core/categories/expense_category.dart';

/// Gestion des motifs : activer/désactiver, créer des catégories
/// personnalisées, et consulter/supprimer les règles d'auto-catégorisation
/// (« toujours ranger X ici »). Accessible depuis l'écran Budget et les
/// Paramètres.
class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Catégories & règles'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Motifs'),
            Tab(text: 'Règles auto'),
          ]),
        ),
        body: const TabBarView(children: [
          _CategoriesTab(),
          _RulesTab(),
        ]),
      ),
    );
  }
}

class _CategoriesTab extends ConsumerWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catsAsync = ref.watch(allExpenseCategoriesProvider);
    return catsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (cats) {
        return Scaffold(
          body: ListView(
            children: [
              for (final c in cats)
                ListTile(
                  leading: Text(c.icon, style: const TextStyle(fontSize: 22)),
                  title: Text(c.label),
                  subtitle: Text(
                    '${c.direction == 'in' ? 'Revenu' : c.direction == 'out' ? 'Dépense' : 'Mixte'}'
                    '${c.isCustom ? ' · personnalisé (appui long pour modifier)' : ''}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Switch(
                    value: c.isActive,
                    onChanged: (v) async {
                      await CategoryRepository.setActive(c.code, v);
                      invalidateCategoryProviders(ref);
                    },
                  ),
                  onLongPress:
                      c.isCustom ? () => _editCustom(context, ref, c) : null,
                ),
              const SizedBox(height: 80),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _editCustom(context, ref, null),
            icon: const Icon(Icons.add),
            label: const Text('Motif'),
          ),
        );
      },
    );
  }

  Future<void> _editCustom(
      BuildContext context, WidgetRef ref, ExpenseCategory? existing) async {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final iconCtrl = TextEditingController(text: existing?.icon ?? '🏷️');
    var direction = existing?.direction ?? 'out';
    const palette = [
      '#E8590C', '#1971C2', '#2F9E44', '#9C36B5', '#E03131',
      '#F08C00', '#0C8599', '#5C940D', '#D6336C', '#495057',
    ];
    var color = existing?.colorHex ?? palette.first;

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(existing == null ? 'Nouveau motif' : 'Modifier le motif',
                  style: Theme.of(ctx)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: TextField(
                      controller: iconCtrl,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22),
                      decoration: const InputDecoration(labelText: 'Icône'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: labelCtrl,
                      decoration: const InputDecoration(labelText: 'Nom'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'out', label: Text('Dépense')),
                  ButtonSegment(value: 'in', label: Text('Revenu')),
                  ButtonSegment(value: 'both', label: Text('Mixte')),
                ],
                selected: {direction},
                onSelectionChanged: (s) =>
                    setSheet(() => direction = s.first),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: palette
                    .map((p) => GestureDetector(
                          onTap: () => setSheet(() => color = p),
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Color(
                                int.parse('FF${p.substring(1)}', radix: 16)),
                            child: color == p
                                ? const Icon(Icons.check,
                                    size: 16, color: Colors.white)
                                : null,
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (saved != true || labelCtrl.text.trim().isEmpty) return;
    if (existing == null) {
      await CategoryRepository.createCustom(
        label: labelCtrl.text,
        icon: iconCtrl.text.trim(),
        colorHex: color,
        direction: direction,
      );
    } else {
      await CategoryRepository.update(existing.copyWith(
        label: labelCtrl.text.trim(),
        icon: iconCtrl.text.trim(),
        colorHex: color,
      ));
    }
    invalidateCategoryProviders(ref);
  }
}

class _RulesTab extends ConsumerWidget {
  const _RulesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(categoryRulesProvider);
    final catMap = ref.watch(categoriesByCodeProvider).valueOrNull ?? {};

    return rulesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (rules) {
        if (rules.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Aucune règle.\n\nQuand vous catégorisez une dépense, cochez '
                '« toujours ranger ici » pour créer une règle : les prochains '
                'paiements du même bénéficiaire seront rangés automatiquement.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return ListView.separated(
          itemCount: rules.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final r = rules[i];
            final cat = catMap[r['category']];
            final type = r['match_type'] as String;
            final label = switch (type) {
              'phone' => 'Numéro',
              'name' => 'Nom contient',
              'type' => 'Type',
              _ => type,
            };
            return ListTile(
              leading: Text(cat?.icon ?? '🏷️',
                  style: const TextStyle(fontSize: 20)),
              title: Text('${r['match_value']}'),
              subtitle: Text('$label → ${cat?.label ?? r['category']}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await CategoryRepository.deleteRule(r['id'] as String);
                  ref.invalidate(categoryRulesProvider);
                },
              ),
            );
          },
        );
      },
    );
  }
}
