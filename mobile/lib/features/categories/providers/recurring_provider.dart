import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';

/// Une série de paiements récurrents détectée (loyer, abonnement, envoi
/// mensuel à un proche, tontine...). Purement calculée depuis l'historique
/// des transactions — aucune table dédiée.
class RecurringSeries {
  final String label; // nom du bénéficiaire, ou numéro à défaut
  final String phone;
  final double typicalAmount; // médiane des montants
  final int count;
  final int avgIntervalDays;
  final DateTime lastDate;
  final String? dominantCategory; // motif le plus fréquent de la série

  const RecurringSeries({
    required this.label,
    required this.phone,
    required this.typicalAmount,
    required this.count,
    required this.avgIntervalDays,
    required this.lastDate,
    this.dominantCategory,
  });

  /// Prochaine échéance estimée (dernière + intervalle moyen).
  DateTime get nextExpected =>
      lastDate.add(Duration(days: avgIntervalDays));

  /// La série a-t-elle des dépenses encore non catégorisées ?
  bool get needsCategory => dominantCategory == null;
}

/// Paiements récurrents détectés (compte Particulier) : au moins 3
/// occurrences vers le même bénéficiaire, montants proches (± 25 % autour
/// de la médiane), espacées d'environ 1 à 5 semaines à ~1 trimestre — ce
/// qui couvre loyer/abonnement mensuel comme tontine hebdo. Trié par
/// montant typique décroissant.
final recurringPaymentsProvider =
    FutureProvider<List<RecurringSeries>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  final since = DateTime.now()
      .subtract(const Duration(days: 200))
      .toIso8601String();

  final rows = await db.rawQuery('''
    SELECT
      COALESCE(NULLIF(t.client_name, ''), t.client_phone) AS label,
      t.client_phone AS phone,
      t.amount AS amount,
      t.category AS category,
      t.created_at AS created_at
    FROM transactions t
    WHERE t.status = 'completed' AND t.direction = 'out'
      AND t.created_at >= ?
      AND (t.client_phone != '' OR t.client_name IS NOT NULL)
    ORDER BY label, t.created_at ASC
  ''', [since]);

  final groups = <String, List<Map<String, Object?>>>{};
  for (final r in rows) {
    (groups[r['label'] as String] ??= []).add(r);
  }

  final series = <RecurringSeries>[];
  for (final entry in groups.entries) {
    final txs = entry.value;
    if (txs.length < 3) continue;

    final amounts = txs.map((t) => (t['amount'] as num).toDouble()).toList()
      ..sort();
    final median = amounts[amounts.length ~/ 2];
    if (median <= 0) continue;

    // Garde les occurrences proches de la médiane (± 25 %), il faut qu'il en
    // reste au moins 3.
    final regular = txs.where((t) {
      final a = (t['amount'] as num).toDouble();
      return (a - median).abs() <= median * 0.25;
    }).toList();
    if (regular.length < 3) continue;

    final dates = regular
        .map((t) => DateTime.parse(t['created_at'] as String))
        .toList()
      ..sort();
    final intervals = <int>[];
    for (var i = 1; i < dates.length; i++) {
      intervals.add(dates[i].difference(dates[i - 1]).inDays);
    }
    if (intervals.length < 2) continue;
    final avgInterval =
        (intervals.reduce((a, b) => a + b) / intervals.length).round();
    // Cadence plausible : hebdo (~7 j) à trimestrielle (~95 j).
    if (avgInterval < 5 || avgInterval > 95) continue;
    // Régularité : chaque écart doit rester dans [0,5× ; 1,75×] la moyenne —
    // sinon ce n'est pas un vrai rythme (ex: 1 j puis 77 j).
    final minGap = intervals.reduce((a, b) => a < b ? a : b);
    final maxGap = intervals.reduce((a, b) => a > b ? a : b);
    if (minGap < avgInterval * 0.5 || maxGap > avgInterval * 1.75) continue;

    // Motif dominant.
    final catCounts = <String, int>{};
    for (final t in regular) {
      final c = t['category'] as String?;
      if (c != null && c.isNotEmpty) {
        catCounts[c] = (catCounts[c] ?? 0) + 1;
      }
    }
    String? dominant;
    if (catCounts.isNotEmpty) {
      dominant = catCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
    }

    series.add(RecurringSeries(
      label: entry.key,
      phone: (regular.first['phone'] as String?) ?? '',
      typicalAmount: median,
      count: regular.length,
      avgIntervalDays: avgInterval,
      lastDate: dates.last,
      dominantCategory: dominant,
    ));
  }

  series.sort((a, b) => b.typicalAmount.compareTo(a.typicalAmount));
  return series;
});

/// Série récurrente correspondant à un bénéficiaire donné (nom ou numéro) —
/// pour signaler « paiement récurrent » sur l'écran de catégorisation.
final recurringForBeneficiaryProvider =
    FutureProvider.family<RecurringSeries?, String>((ref, label) async {
  final all = await ref.watch(recurringPaymentsProvider.future);
  final lower = label.trim().toLowerCase();
  for (final s in all) {
    if (s.label.toLowerCase() == lower || s.phone == label.trim()) return s;
  }
  return null;
});
