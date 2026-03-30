import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';

/// Graphique en barres — Dépôts vs Retraits par jour
class BarChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool compact;

  const BarChartWidget({super.key, required this.data, this.compact = false});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Pas de données'));
    }

    // Limiter aux N derniers jours si trop de données
    final displayData = data.length > 14 ? data.sublist(data.length - 14) : data;
    final dayFormat = DateFormat('E', 'fr_FR');
    final dateFormat = DateFormat('dd/MM');

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxY(displayData),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final value = rod.toY;
              final label = rodIndex == 0 ? 'Dépôts' : 'Retraits';
              return BarTooltipItem(
                '$label\n${NumberFormat.compact(locale: 'fr_FR').format(value)} FCFA',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index >= 0 && index < displayData.length) {
                  final date = displayData[index]['date'] as DateTime;
                  final text = displayData.length <= 7
                      ? dayFormat.format(date)
                      : dateFormat.format(date);
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(text, style: const TextStyle(fontSize: 10)),
                  );
                }
                return const SizedBox.shrink();
              },
              interval: displayData.length > 10 ? 2 : 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: !compact,
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(
                NumberFormat.compact(locale: 'fr_FR').format(value),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withAlpha(30),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(displayData.length, (index) {
          final d = displayData[index];
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: (d['deposits'] as double),
                color: AppColors.depositColor,
                width: displayData.length > 10 ? 6 : 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
              BarChartRodData(
                toY: (d['withdrawals'] as double),
                color: AppColors.withdrawColor,
                width: displayData.length > 10 ? 6 : 12,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }),
      ),
    );
  }

  double _getMaxY(List<Map<String, dynamic>> data) {
    double max = 0;
    for (final d in data) {
      final dep = d['deposits'] as double;
      final wit = d['withdrawals'] as double;
      if (dep > max) max = dep;
      if (wit > max) max = wit;
    }
    return max > 0 ? max * 1.2 : 10000;
  }
}
