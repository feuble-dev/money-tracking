/// Filtre pour les transactions
class TransactionFilter {
  final String? operatorId;
  final String? clientId;
  final String? transactionType;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? searchQuery; // Recherche par numéro ou nom

  const TransactionFilter({
    this.operatorId,
    this.clientId,
    this.transactionType,
    this.dateFrom,
    this.dateTo,
    this.searchQuery,
  });

  bool get hasFilter =>
      operatorId != null ||
      clientId != null ||
      transactionType != null ||
      dateFrom != null ||
      (searchQuery != null && searchQuery!.isNotEmpty);

  TransactionFilter copyWith({
    Object? operatorId = _sentinel,
    Object? clientId = _sentinel,
    Object? transactionType = _sentinel,
    Object? dateFrom = _sentinel,
    Object? dateTo = _sentinel,
    Object? searchQuery = _sentinel,
  }) => TransactionFilter(
    operatorId: operatorId == _sentinel ? this.operatorId : operatorId as String?,
    clientId: clientId == _sentinel ? this.clientId : clientId as String?,
    transactionType: transactionType == _sentinel ? this.transactionType : transactionType as String?,
    dateFrom: dateFrom == _sentinel ? this.dateFrom : dateFrom as DateTime?,
    dateTo: dateTo == _sentinel ? this.dateTo : dateTo as DateTime?,
    searchQuery: searchQuery == _sentinel ? this.searchQuery : searchQuery as String?,
  );
}

const _sentinel = Object();
