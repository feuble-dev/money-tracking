import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';

/// Graphique linéaire — Dépôts et Retraits superposés
class LineChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final bool showBothLines;

  const LineChartWidget({
    super.key,
    required this.data,
    this.showBothLines = true,
  });

  double _calcInterval() {
    if (data.length <= 7) return 1;
    if (data.length <= 14) return 2;
    if (data.length <= 30) return 5;
    return (data.length / 6).ceilToDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Pas de données'));
    }

    return LineChart(
      LineChartData(
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) {
              return spots.map((spot) {
                final index = spot.x.toInt();
                if (index < 0 || index >= data.length) return null;
                final date = data[index]['date'] as DateTime;
                final label = spot.barIndex == 0 ? 'Entrées' : 'Sorties';
                final color = spot.barIndex == 0
                    ? AppColors.depositColor
                    : AppColors.withdrawColor;
                return LineTooltipItem(
                  '${DateFormat('dd/MM', 'fr_FR').format(date)}\n$label: ${NumberFormat.compact(locale: 'fr_FR').format(spot.y)} FCFA',
                  TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
                );
              }).toList();
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.grey.withAlpha(30),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: _calcInterval(),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                final date = data[index]['date'] as DateTime;
                return SideTitleWidget(
                  meta: meta,
                  child: Transform.rotate(
                    angle: data.length > 10 ? -0.5 : 0,
                    child: Text(
                      DateFormat('dd/MM').format(date),
                      style: const TextStyle(fontSize: 9),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
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
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Ligne dépôts
          LineChartBarData(
            spots: List.generate(data.length, (i) =>
              FlSpot(i.toDouble(), (data[i]['deposits'] as double)),
            ),
            isCurved: true,
            color: AppColors.depositColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: data.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.depositColor.withAlpha(20),
            ),
          ),
          if (showBothLines)
            // Ligne retraits
            LineChartBarData(
              spots: List.generate(data.length, (i) =>
                FlSpot(i.toDouble(), (data[i]['withdrawals'] as double)),
              ),
              isCurved: true,
              color: AppColors.withdrawColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(show: data.length <= 14),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.withdrawColor.withAlpha(20),
              ),
            ),
        ],
      ),
    );
  }
}
