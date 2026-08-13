import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Graphique camembert — Répartition par opérateur
class PieChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const PieChartWidget({super.key, required this.data});

  static const _colors = [
    Color(0xFF1565C0),
    Color(0xFF4CAF50),
    Color(0xFF2E7D32),
    Color(0xFFC62828),
    Color(0xFF6A1B9A),
    Color(0xFF00838F),
    Color(0xFFEF6C00),
  ];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Pas de données'));
    }

    final total = data.fold<double>(
        0, (sum, d) => sum + (d['total'] as num).toDouble());
    if (total == 0) {
      return const Center(child: Text('Aucune transaction'));
    }

    final currencyFormat =
        NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

    return Row(
      children: [
        // Camembert
        Expanded(
          flex: 3,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: List.generate(data.length, (index) {
                final d = data[index];
                final value = (d['total'] as num).toDouble();
                final percentage = (value / total * 100);
                return PieChartSectionData(
                  color: _colors[index % _colors.length],
                  value: value,
                  title: '${percentage.toStringAsFixed(0)}%',
                  titleStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  radius: 50,
                );
              }),
            ),
          ),
        ),
        // Légende
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(data.length, (index) {
              final d = data[index];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: _colors[index % _colors.length],
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d['name'] as String,
                            style: const TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            currencyFormat.format(d['total']),
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}
