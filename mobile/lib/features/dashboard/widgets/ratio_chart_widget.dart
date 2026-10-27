import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/amount_text.dart';

/// Graphique ratio dépôts / retraits (donut + légende)
class RatioChartWidget extends StatelessWidget {
  final double deposits;
  final double withdrawals;

  const RatioChartWidget({
    super.key,
    required this.deposits,
    required this.withdrawals,
  });

  @override
  Widget build(BuildContext context) {
    final total = deposits + withdrawals;
    if (total == 0) {
      return const Center(child: Text('Aucune transaction'));
    }

    final depPercent = (deposits / total * 100);
    final witPercent = (withdrawals / total * 100);
    final currencyFormat = NumberFormat.currency(
        locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    // Donut à gauche, légende à droite : tient dans les 180 px du parent
    // sans défilement interne (l'ancienne pile verticale débordait et
    // obligeait à scroller À L'INTÉRIEUR de la carte).
    return Row(
      children: [
        SizedBox(
          width: 120,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 22,
              sections: [
                PieChartSectionData(
                  color: AppColors.depositColor,
                  value: deposits,
                  title: '${depPercent.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11,
                  ),
                  radius: 32,
                  titlePositionPercentageOffset: 0.55,
                ),
                PieChartSectionData(
                  color: AppColors.withdrawColor,
                  value: withdrawals,
                  title: '${witPercent.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11,
                  ),
                  radius: 32,
                  titlePositionPercentageOffset: 0.55,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legendRow('Entrées', AppColors.depositColor,
                  currencyFormat.format(deposits), '${depPercent.toStringAsFixed(1)}%'),
              const SizedBox(height: 10),
              _legendRow('Sorties', AppColors.withdrawColor,
                  currencyFormat.format(withdrawals), '${witPercent.toStringAsFixed(1)}%'),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 6),
              AmountText(
                'Volume : ${currencyFormat.format(total)}',
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _legendRow(String label, Color color, String amount, String percent) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600, color: color)),
              AmountText(amount, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(percent,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
