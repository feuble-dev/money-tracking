import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';

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

    return Row(
      children: [
        // Donut chart
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 35,
              sections: [
                PieChartSectionData(
                  color: AppColors.depositColor,
                  value: deposits,
                  title: '${depPercent.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  radius: 45,
                ),
                PieChartSectionData(
                  color: AppColors.withdrawColor,
                  value: withdrawals,
                  title: '${witPercent.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  radius: 45,
                ),
              ],
            ),
          ),
        ),
        // Légende
        Expanded(
          flex: 3,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _legendRow(
                'Dépôts',
                AppColors.depositColor,
                currencyFormat.format(deposits),
                '${depPercent.toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 12),
              _legendRow(
                'Retraits',
                AppColors.withdrawColor,
                currencyFormat.format(withdrawals),
                '${witPercent.toStringAsFixed(1)}%',
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              Text(
                'Volume total: ${currencyFormat.format(total)}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
              Text(amount, style: const TextStyle(fontSize: 11)),
            ],
          ),
        ),
        Text(percent,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
