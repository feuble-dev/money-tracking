import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../format/formats.dart';
import '../notifications/notification_service.dart';
import '../onboarding/onboarding_state.dart';

/// Chiffres d'une journée d'agence.
class DaySummary {
  final int operations;
  final double volume;
  final double commissions;
  /// Commissions du même jour de la semaine précédente (comparaison juste :
  /// un lundi se compare à un lundi, pas à un dimanche calme).
  final double commissionsWeekBefore;

  const DaySummary({
    required this.operations,
    required this.volume,
    required this.commissions,
    required this.commissionsWeekBefore,
  });

  /// Texte de la notification.
  String get text {
    final b = StringBuffer(
        '$operations opération${operations > 1 ? 's' : ''}, '
        '${AppFormats.fcfa(volume)} traités, '
        '${AppFormats.fcfa(commissions)} de commissions');
    if (commissionsWeekBefore > 0) {
      final delta =
          ((commissions - commissionsWeekBefore) / commissionsWeekBefore * 100)
              .round();
      b.write(' (${delta >= 0 ? '+' : ''}$delta % vs la semaine dernière)');
    }
    b.write('.');
    return b.toString();
  }
}

/// Bilan de la veille pour une agence, poussé une fois par jour au premier
/// démarrage : l'agent voit sa journée d'hier sans ouvrir de statistiques.
/// Silencieux un jour sans activité. Équivalent agence du bilan mensuel
/// des particuliers (MonthlySummaryService).
class DailySummaryService {
  static const _prefKey = 'last_daily_summary_day';

  static Future<void> maybeShow() async {
    try {
      if (await OnboardingStatusService().getAccountType() != 'agence') return;
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now();
      final key = _dayKey(today);
      if (prefs.getString(_prefKey) == key) return;
      await prefs.setString(_prefKey, key);

      final yesterday = DateTime(today.year, today.month, today.day - 1);
      final db = await DatabaseHelper.instance.database;
      final summary = await summarize(db, yesterday);
      if (summary == null) return;
      await NotificationService().showSummary(
        id: 920004,
        title: 'Votre journée d\'hier',
        body: summary.text,
        payload: 'commissions',
      );
    } catch (e) {
      debugPrint('[DailySummary] erreur: $e');
    }
  }

  /// Chiffres du jour [day] (opérations confirmées seulement), ou null sans
  /// activité.
  @visibleForTesting
  static Future<DaySummary?> summarize(DatabaseExecutor db, DateTime day) async {
    Future<Map<String, Object?>> totals(DateTime d) async {
      final start = DateTime(d.year, d.month, d.day);
      final end = start.add(const Duration(days: 1));
      final rows = await db.rawQuery('''
        SELECT COUNT(*) AS n, COALESCE(SUM(amount), 0) AS volume,
               COALESCE(SUM(commission), 0) AS commissions
        FROM transactions
        WHERE status = 'completed' AND created_at >= ? AND created_at < ?
      ''', [start.toIso8601String(), end.toIso8601String()]);
      return rows.first;
    }

    final t = await totals(day);
    final n = (t['n'] as num).toInt();
    if (n == 0) return null;
    final before = await totals(day.subtract(const Duration(days: 7)));
    return DaySummary(
      operations: n,
      volume: (t['volume'] as num).toDouble(),
      commissions: (t['commissions'] as num).toDouble(),
      commissionsWeekBefore: (before['commissions'] as num).toDouble(),
    );
  }

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
