/// Périodes prédéfinies pour le dashboard
enum DashboardPeriod {
  today('Aujourd\'hui'),
  yesterday('Hier'),
  week('7 jours'),
  twoWeeks('14 jours'),
  month('30 jours'),
  threeMonths('3 mois'),
  custom('Personnalisé');

  final String label;
  const DashboardPeriod(this.label);

  /// Retourne les bornes [start, end] pour la période
  (DateTime, DateTime) get dateRange {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);

    switch (this) {
      case DashboardPeriod.today:
        return (todayStart, todayEnd);
      case DashboardPeriod.yesterday:
        final yStart = todayStart.subtract(const Duration(days: 1));
        final yEnd = todayEnd.subtract(const Duration(days: 1));
        return (yStart, yEnd);
      case DashboardPeriod.week:
        return (todayStart.subtract(const Duration(days: 6)), todayEnd);
      case DashboardPeriod.twoWeeks:
        return (todayStart.subtract(const Duration(days: 13)), todayEnd);
      case DashboardPeriod.month:
        return (todayStart.subtract(const Duration(days: 29)), todayEnd);
      case DashboardPeriod.threeMonths:
        return (todayStart.subtract(const Duration(days: 89)), todayEnd);
      case DashboardPeriod.custom:
        return (todayStart.subtract(const Duration(days: 29)), todayEnd);
    }
  }
}

/// Filtre complet du dashboard
class DashboardFilter {
  final DashboardPeriod? period; // null = pas de filtre de période
  final String? operatorId;
  final DateTime? customStart;
  final DateTime? customEnd;

  const DashboardFilter({
    this.period = DashboardPeriod.month,
    this.operatorId,
    this.customStart,
    this.customEnd,
  });

  /// Bornes effectives (prend en compte le custom et l'absence de filtre)
  (DateTime, DateTime) get effectiveRange {
    if (period == null) {
      // Pas de filtre → tout depuis le début
      return (DateTime(2020), DateTime.now());
    }
    if (period == DashboardPeriod.custom &&
        customStart != null && customEnd != null) {
      return (customStart!, customEnd!);
    }
    return period!.dateRange;
  }

  bool get hasFilter => period != null;

  DashboardFilter copyWith({
    DashboardPeriod? Function()? period,
    String? Function()? operatorId,
    DateTime? customStart,
    DateTime? customEnd,
  }) => DashboardFilter(
    period: period != null ? period() : this.period,
    operatorId: operatorId != null ? operatorId() : this.operatorId,
    customStart: customStart ?? this.customStart,
    customEnd: customEnd ?? this.customEnd,
  );
}
