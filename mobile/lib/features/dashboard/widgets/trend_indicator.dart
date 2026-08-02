import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Indicateur de tendance (flèche + pourcentage par rapport à la période précédente)
class TrendIndicator extends StatelessWidget {
  final double percentage;
  final String label;

  const TrendIndicator({
    super.key,
    required this.percentage,
    this.label = 'vs période précédente',
  });

  @override
  Widget build(BuildContext context) {
    final isUp = percentage >= 0;
    final color = isUp ? AppColors.depositColor : AppColors.withdrawColor;
    final icon = isUp ? Icons.trending_up : Icons.trending_down;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          '${isUp ? '+' : ''}${percentage.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
        ),
      ],
    );
  }
}
