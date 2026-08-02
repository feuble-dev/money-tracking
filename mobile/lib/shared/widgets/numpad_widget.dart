import 'package:flutter/material.dart';

/// Pavé numérique réutilisable pour la saisie du PIN
class NumpadWidget extends StatelessWidget {
  /// Callback quand un chiffre est pressé (0-9)
  final ValueChanged<int> onDigitPressed;

  /// Callback quand le bouton effacer est pressé
  final VoidCallback onDeletePressed;

  /// Widget optionnel en bas à gauche (ex: bouton biométrie)
  final Widget? bottomLeftWidget;

  const NumpadWidget({
    super.key,
    required this.onDigitPressed,
    required this.onDeletePressed,
    this.bottomLeftWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int row = 0; row < 4; row++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                if (row < 3) ...[
                  for (int col = 0; col < 3; col++)
                    _buildDigitButton(context, row * 3 + col + 1),
                ] else ...[
                  bottomLeftWidget ?? const SizedBox(width: 72),
                  _buildDigitButton(context, 0),
                  _buildDeleteButton(),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDigitButton(BuildContext context, int digit) {
    return InkWell(
      onTap: () => onDigitPressed(digit),
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 72,
        height: 72,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Text(
          digit.toString(),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildDeleteButton() {
    return InkWell(
      onTap: onDeletePressed,
      borderRadius: BorderRadius.circular(40),
      child: const SizedBox(
        width: 72,
        height: 72,
        child: Icon(Icons.backspace_outlined, size: 28),
      ),
    );
  }
}
