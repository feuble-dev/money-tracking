import 'package:flutter/material.dart';

/// Montant affiché sur **une seule ligne** qui rétrécit pour tenir dans la
/// place disponible, au lieu de déborder (« RenderFlex overflowed ») ou de
/// passer à la ligne au milieu du nombre quand les sommes grossissent
/// (ex. « 12 500 000 FCFA » sur un petit écran, ou police système agrandie).
///
/// Dans une `Row`, l'envelopper dans `Flexible`/`Expanded` : sans contrainte
/// de largeur, `FittedBox` n'a rien à quoi s'ajuster.
class AmountText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final AlignmentGeometry alignment;
  final TextAlign? textAlign;

  const AmountText(
    this.text, {
    super.key,
    this.style,
    this.alignment = AlignmentDirectional.centerStart,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        softWrap: false,
        textAlign: textAlign,
      ),
    );
  }
}
