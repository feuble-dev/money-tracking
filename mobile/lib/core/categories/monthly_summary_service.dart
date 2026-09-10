import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../format/formats.dart';
import '../notifications/notification_service.dart';
import '../onboarding/onboarding_state.dart';
import 'category_repository.dart';

/// Récapitulatif mensuel des dépenses (compte Particulier) — poussé une
/// seule fois par mois calendaire, au démarrage de l'app. Non bloquant,
/// silencieux s'il n'y a rien à dire.
class MonthlySummaryService {
  static const _prefKey = 'last_monthly_summary_ym';

  static Future<void> maybeShow() async {
    try {
      final accountType = await OnboardingStatusService().getAccountType();
      if (accountType != 'particulier') return;

      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      final currentYm =
          '${now.year}-${now.month.toString().padLeft(2, '0')}';
      if (prefs.getString(_prefKey) == currentYm) return;

      // Mois écoulé.
      final prevMonthEnd = DateTime(now.year, now.month, 1);
      final prevMonthStart =
          DateTime(prevMonthEnd.year, prevMonthEnd.month - 1, 1);

      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery('''
        SELECT COALESCE(NULLIF(category, ''), '') AS cat,
               COALESCE(SUM(amount), 0) AS total, COUNT(*) AS c
        FROM transactions
        WHERE status = 'completed' AND direction = 'out'
          AND created_at >= ? AND created_at < ?
        GROUP BY cat
      ''', [prevMonthStart.toIso8601String(), prevMonthEnd.toIso8601String()]);

      // On marque le mois comme traité même si vide, pour ne pas re-checker
      // à chaque démarrage.
      await prefs.setString(_prefKey, currentYm);
      if (rows.isEmpty) return;

      final total =
          rows.fold<double>(0, (s, r) => s + (r['total'] as num).toDouble());
      if (total <= 0) return;

      // Comparaison mois d'avant l'avant.
      final prevPrevStart =
          DateTime(prevMonthStart.year, prevMonthStart.month - 1, 1);
      final prevRow = await db.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS total FROM transactions
        WHERE status = 'completed' AND direction = 'out'
          AND created_at >= ? AND created_at < ?
      ''', [prevPrevStart.toIso8601String(), prevMonthStart.toIso8601String()]);
      final prevTotal = (prevRow.first['total'] as num).toDouble();

      // Top motif nommé (hors non catégorisé).
      final named = rows.where((r) => (r['cat'] as String).isNotEmpty).toList()
        ..sort((a, b) =>
            (b['total'] as num).compareTo(a['total'] as num));
      String topLabel = '';
      double topAmount = 0;
      if (named.isNotEmpty) {
        final cat = await CategoryRepository.getByCode(named.first['cat'] as String);
        topLabel = cat?.label ?? (named.first['cat'] as String);
        topAmount = (named.first['total'] as num).toDouble();
      }

      final currency = AppFormats.currency;
      final monthName = DateFormat.MMMM('fr_FR').format(prevMonthStart);

      final buffer = StringBuffer('${currency.format(total)} dépensés');
      if (prevTotal > 0) {
        final delta = ((total - prevTotal) / prevTotal * 100).round();
        buffer.write(delta >= 0 ? ' (+$delta% vs mois précédent)' : ' ($delta% vs mois précédent)');
      }
      buffer.write('.');
      if (topLabel.isNotEmpty) {
        buffer.write(' Top : $topLabel ${currency.format(topAmount)}.');
      }

      await NotificationService().showMonthlySummary(
        title: 'Bilan de ${_cap(monthName)}',
        body: buffer.toString(),
      );
    } catch (e) {
      debugPrint('[MonthlySummary] erreur: $e');
    }
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}
