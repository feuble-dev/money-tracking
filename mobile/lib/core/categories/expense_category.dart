import 'package:flutter/material.dart';

/// Catégorie de motif d'une transaction (« dépense en nourriture », « argent
/// reçu d'un proche »...). C'est un concept **distinct** du type de
/// transaction (D3) : « Transfert sortant » est un *type*, « Nourriture » est
/// un *motif*. Purement local — les habitudes de dépense d'un particulier
/// sont des données sensibles qui n'ont pas à remonter au serveur (l'app est
/// offline-first). Seul le cas multi-téléphone d'un même Particulier fait
/// transiter `category` via `sync` (ses deux SIM, son propre compte).
class ExpenseCategory {
  final String code;
  final String label;

  /// Emoji affiché — choisi plutôt qu'une icône Material pour une lecture
  /// immédiate (contexte Burkina Faso, alphabétisation variable) et pour
  /// éviter une table de correspondance nom→IconData à maintenir.
  final String icon;

  /// Couleur d'accent, stockée en hex `#RRGGBB`.
  final String colorHex;

  /// 'out' (dépense), 'in' (revenu) ou 'both'.
  final String direction;

  final bool isCustom;
  final int sortOrder;
  final bool isActive;

  const ExpenseCategory({
    required this.code,
    required this.label,
    required this.icon,
    required this.colorHex,
    required this.direction,
    this.isCustom = false,
    this.sortOrder = 0,
    this.isActive = true,
  });

  Color get color {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  bool matchesDirection(String? txDirection) =>
      direction == 'both' || txDirection == null || direction == txDirection;

  Map<String, Object?> toMap() => {
        'code': code,
        'label': label,
        'icon': icon,
        'color': colorHex,
        'direction': direction,
        'is_custom': isCustom ? 1 : 0,
        'sort_order': sortOrder,
        'is_active': isActive ? 1 : 0,
      };

  factory ExpenseCategory.fromMap(Map<String, Object?> m) => ExpenseCategory(
        code: m['code'] as String,
        label: m['label'] as String,
        icon: (m['icon'] as String?) ?? '❓',
        colorHex: (m['color'] as String?) ?? '#64748B',
        direction: (m['direction'] as String?) ?? 'both',
        isCustom: (m['is_custom'] as int? ?? 0) == 1,
        sortOrder: (m['sort_order'] as int? ?? 0),
        isActive: (m['is_active'] as int? ?? 1) == 1,
      );

  ExpenseCategory copyWith({
    String? label,
    String? icon,
    String? colorHex,
    int? sortOrder,
    bool? isActive,
  }) =>
      ExpenseCategory(
        code: code,
        label: label ?? this.label,
        icon: icon ?? this.icon,
        colorHex: colorHex ?? this.colorHex,
        direction: direction,
        isCustom: isCustom,
        sortOrder: sortOrder ?? this.sortOrder,
        isActive: isActive ?? this.isActive,
      );
}

/// Code réservé — « Autre / Non catégorisé ». Une transaction avec
/// `category == null` est *non catégorisée* (elle apparaît dans la file
/// « à catégoriser ») ; une transaction explicitement rangée ici par
/// l'utilisateur est catégorisée mais sans motif précis.
const kCategoryOther = 'autre';

/// Codes de catégorie déduits automatiquement du type de transaction, sans
/// jamais déranger l'utilisateur (voir `CategoryRepository.autoCategoryFor`).
const kCategoryCreditTel = 'credit_tel';
const kCategoryFrais = 'frais';

/// Catalogue par défaut, orienté Burkina Faso. Seedé en base à la création
/// et à la migration v15 (INSERT OR IGNORE par `code` — réordonner/masquer
/// côté utilisateur n'est jamais écrasé).
const List<ExpenseCategory> kDefaultExpenseCategories = [
  // ---- Dépenses ----
  ExpenseCategory(code: 'alimentation', label: 'Alimentation / Marché', icon: '🍚', colorHex: '#E8590C', direction: 'out', sortOrder: 10),
  ExpenseCategory(code: 'courses', label: 'Courses & achats divers', icon: '🛒', colorHex: '#F08C00', direction: 'out', sortOrder: 20),
  ExpenseCategory(code: 'transport', label: 'Transport / Carburant', icon: '🚗', colorHex: '#1971C2', direction: 'out', sortOrder: 30),
  ExpenseCategory(code: 'factures', label: 'Factures (SONABEL, ONEA, internet)', icon: '💡', colorHex: '#F59F00', direction: 'out', sortOrder: 40),
  ExpenseCategory(code: kCategoryCreditTel, label: 'Crédit / Forfait téléphone', icon: '📱', colorHex: '#7048E8', direction: 'out', sortOrder: 50),
  ExpenseCategory(code: 'logement', label: 'Loyer / Logement', icon: '🏠', colorHex: '#0C8599', direction: 'out', sortOrder: 60),
  ExpenseCategory(code: 'sante', label: 'Santé / Pharmacie', icon: '🏥', colorHex: '#E03131', direction: 'out', sortOrder: 70),
  ExpenseCategory(code: 'education', label: 'Éducation / Scolarité', icon: '🎓', colorHex: '#1C7ED6', direction: 'out', sortOrder: 80),
  ExpenseCategory(code: 'famille', label: 'Envoi à la famille / aux proches', icon: '👪', colorHex: '#37B24D', direction: 'out', sortOrder: 90),
  ExpenseCategory(code: 'ceremonies', label: 'Cérémonies / Dons', icon: '🎁', colorHex: '#D6336C', direction: 'out', sortOrder: 100),
  ExpenseCategory(code: 'religion', label: 'Dîme / Offrande / Zakat', icon: '🙏', colorHex: '#9C36B5', direction: 'out', sortOrder: 110),
  ExpenseCategory(code: 'habillement', label: 'Habillement', icon: '👕', colorHex: '#C2255C', direction: 'out', sortOrder: 120),
  ExpenseCategory(code: 'business', label: 'Marchandise / Business', icon: '💼', colorHex: '#5C940D', direction: 'out', sortOrder: 130),
  ExpenseCategory(code: 'epargne', label: 'Épargne / Tontine / Cotisation', icon: '💰', colorHex: '#2F9E44', direction: 'both', sortOrder: 140),
  ExpenseCategory(code: 'dette', label: 'Remboursement de dette / Prêt', icon: '🔁', colorHex: '#495057', direction: 'both', sortOrder: 150),
  ExpenseCategory(code: 'loisirs', label: 'Loisirs / Sorties', icon: '🎉', colorHex: '#F76707', direction: 'out', sortOrder: 160),
  ExpenseCategory(code: 'reparations', label: 'Réparations / Entretien', icon: '🔧', colorHex: '#868E96', direction: 'out', sortOrder: 170),
  ExpenseCategory(code: 'agri_elevage', label: 'Agriculture / Élevage', icon: '🌾', colorHex: '#66A80F', direction: 'out', sortOrder: 180),
  ExpenseCategory(code: kCategoryFrais, label: 'Frais (retrait, transfert)', icon: '🏦', colorHex: '#adb5bd', direction: 'out', sortOrder: 190),

  // ---- Revenus ----
  ExpenseCategory(code: 'salaire', label: 'Salaire / Revenu', icon: '💵', colorHex: '#2F9E44', direction: 'in', sortOrder: 210),
  ExpenseCategory(code: 'argent_recu', label: "Argent reçu d'un proche", icon: '🤝', colorHex: '#37B24D', direction: 'in', sortOrder: 220),
  ExpenseCategory(code: 'vente', label: 'Vente / Revenu business', icon: '🏷️', colorHex: '#5C940D', direction: 'in', sortOrder: 230),
  ExpenseCategory(code: 'remboursement', label: 'Remboursement reçu', icon: '↩️', colorHex: '#1971C2', direction: 'in', sortOrder: 240),

  // ---- Fourre-tout ----
  ExpenseCategory(code: kCategoryOther, label: 'Autre', icon: '❓', colorHex: '#64748B', direction: 'both', sortOrder: 900),
];
