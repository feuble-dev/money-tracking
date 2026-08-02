import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Widget affichant 4 points animés pour la saisie du PIN
class PinDots extends StatelessWidget {
  final int filledCount;
  final bool hasError;

  const PinDots({
    super.key,
    required this.filledCount,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < filledCount;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: isFilled ? 20 : 16,
          height: isFilled ? 20 : 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hasError
                ? AppColors.withdrawColor
                : isFilled
                    ? AppColors.primaryColor
                    : Colors.grey.withAlpha(80),
            border: !isFilled && !hasError
                ? Border.all(color: Colors.grey.withAlpha(120), width: 2)
                : null,
          ),
        );
      }),
    );
  }
}
