import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'category_repository.dart';
import 'expense_category.dart';

/// Catégories actives (toutes directions), triées — pour les sélecteurs.
final expenseCategoriesProvider =
    FutureProvider<List<ExpenseCategory>>((ref) async {
  return CategoryRepository.getAll(activeOnly: true);
});

/// Toutes les catégories (même inactives/custom) indexées par code — pour
/// résoudre l'affichage d'une transaction déjà catégorisée.
final categoriesByCodeProvider =
    FutureProvider<Map<String, ExpenseCategory>>((ref) async {
  return CategoryRepository.byCode();
});

/// Nombre de dépenses non catégorisées (badge « à catégoriser »). Invalidé
/// après chaque détection SMS et après chaque catégorisation.
final uncategorizedCountProvider = FutureProvider<int>((ref) async {
  return CategoryRepository.uncategorizedCount(direction: 'out');
});

/// Règles d'auto-catégorisation (écran de gestion).
final categoryRulesProvider =
    FutureProvider<List<Map<String, Object?>>>((ref) async {
  return CategoryRepository.getRules();
});

/// Plafonds mensuels par catégorie (`code -> montant`).
final categoryBudgetsProvider = FutureProvider<Map<String, double>>((ref) async {
  return CategoryRepository.getBudgets();
});

/// Invalide d'un coup tout ce qui dépend des catégories — à appeler après
/// une catégorisation, une règle ajoutée, un budget modifié, ou une
/// détection SMS.
void invalidateCategoryProviders(WidgetRef ref) {
  ref.invalidate(uncategorizedCountProvider);
  ref.invalidate(categoryRulesProvider);
  ref.invalidate(categoryBudgetsProvider);
  ref.invalidate(expenseCategoriesProvider);
  ref.invalidate(categoriesByCodeProvider);
}
