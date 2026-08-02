import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Graphique d'activité par heure (barres horizontales style heatmap)
class HourlyChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const HourlyChartWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Pas de données'));
    }

    final maxCount = data.fold<int>(0, (max, d) {
      final count = d['count'] as int;
      return count > max ? count : max;
    });

    return Column(
      children: data.map((d) {
        final hour = d['hour'] as int;
        final count = d['count'] as int;
        final ratio = maxCount > 0 ? count / maxCount : 0.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                child: Text(
                  '${hour.toString().padLeft(2, '0')}h',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: count > 0 ? FontWeight.w600 : FontWeight.normal,
                    color: count > 0 ? null : Colors.grey,
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        // Fond
                        Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: Colors.grey.withAlpha(20),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        // Barre
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 18,
                          width: constraints.maxWidth * ratio,
                          decoration: BoxDecoration(
                            color: _colorForRatio(ratio),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 28,
                child: Text(
                  count > 0 ? count.toString() : '-',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: count > 0 ? AppColors.primaryColor : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Color _colorForRatio(double ratio) {
    if (ratio > 0.75) return AppColors.primaryColor;
    if (ratio > 0.5) return AppColors.primaryLight;
    if (ratio > 0.25) return AppColors.primaryLight.withAlpha(150);
    return AppColors.primaryLight.withAlpha(80);
  }
}
