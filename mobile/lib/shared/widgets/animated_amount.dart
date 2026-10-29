import 'package:flutter/material.dart';

import '../../core/format/formats.dart';
import 'amount_text.dart';

/// Montant qui « défile » jusqu'à sa nouvelle valeur (solde, total…) au
/// lieu de changer d'un coup. Hérite du comportement d'[AmountText] : une
/// seule ligne, rétrécit plutôt que de déborder. [hidden] masque la valeur.
class AnimatedAmount extends StatelessWidget {
  final double value;
  final TextStyle? style;
  final bool hidden;
  final String prefix;
  final AlignmentGeometry alignment;
  final Duration duration;

  const AnimatedAmount(
    this.value, {
    super.key,
    this.style,
    this.hidden = false,
    this.prefix = '',
    this.alignment = AlignmentDirectional.centerStart,
    this.duration = const Duration(milliseconds: 700),
  });

  @override
  Widget build(BuildContext context) {
    if (hidden) {
      return AmountText('•••••• FCFA', style: style, alignment: alignment);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => AmountText(
        '$prefix${AppFormats.fcfa(v.roundToDouble())}',
        style: style,
        alignment: alignment,
      ),
    );
  }
}
