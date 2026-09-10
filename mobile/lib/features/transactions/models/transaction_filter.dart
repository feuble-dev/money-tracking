/// Filtre pour les transactions.
///
/// `direction` ('in'|'out', D1) remplace `transactionType` comme filtre
/// rapide Entrant/Sortant — filtrer par code littéral ('deposit' vs
/// 'depot' vs 'retrait'...) est fragile depuis que les types viennent du
/// catalogue (D3) : deux opérateurs peuvent avoir des codes différents
/// pour un type "équivalent", et un opérateur custom créé localement
/// utilise 'deposit'/'withdrawal' alors qu'un opérateur du catalogue
/// utilise les codes définis par l'admin (ex: 'depot'/'retrait'). Le sens
/// (direction), lui, est toujours cohérent. `transactionType` reste
/// disponible pour un filtre par type exact si besoin plus tard.
class TransactionFilter {
  final String? operatorId;
  final String? clientId;
  final String? transactionType;
  final String? direction; // 'in' | 'out'
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? searchQuery; // Recherche par numéro ou nom
  // Motif (D-catégories). Valeur spéciale '__uncat__' = non catégorisées.
  final String? category;

  const TransactionFilter({
    this.operatorId,
    this.clientId,
    this.transactionType,
    this.direction,
    this.dateFrom,
    this.dateTo,
    this.searchQuery,
    this.category,
  });

  bool get hasFilter =>
      operatorId != null ||
      clientId != null ||
      transactionType != null ||
      direction != null ||
      dateFrom != null ||
      category != null ||
      (searchQuery != null && searchQuery!.isNotEmpty);

  TransactionFilter copyWith({
    Object? operatorId = _sentinel,
    Object? clientId = _sentinel,
    Object? transactionType = _sentinel,
    Object? direction = _sentinel,
    Object? dateFrom = _sentinel,
    Object? dateTo = _sentinel,
    Object? searchQuery = _sentinel,
    Object? category = _sentinel,
  }) => TransactionFilter(
    operatorId: operatorId == _sentinel ? this.operatorId : operatorId as String?,
    clientId: clientId == _sentinel ? this.clientId : clientId as String?,
    transactionType: transactionType == _sentinel ? this.transactionType : transactionType as String?,
    direction: direction == _sentinel ? this.direction : direction as String?,
    dateFrom: dateFrom == _sentinel ? this.dateFrom : dateFrom as DateTime?,
    dateTo: dateTo == _sentinel ? this.dateTo : dateTo as DateTime?,
    searchQuery: searchQuery == _sentinel ? this.searchQuery : searchQuery as String?,
    category: category == _sentinel ? this.category : category as String?,
  );
}

/// Valeur de [TransactionFilter.category] ciblant les transactions sans motif.
const kFilterUncategorized = '__uncat__';

const _sentinel = Object();
