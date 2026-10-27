import 'package:flutter/services.dart';

/// Saisie de montant FCFA : chiffres uniquement, groupés par milliers avec
/// un espace pendant la frappe (« 1500000 » → « 1 500 000 »). Le curseur
/// reste après le même chiffre, même quand un espace est inséré/retiré
/// avant lui.
///
/// Tous les écrans relisent déjà la valeur en retirant les non-chiffres
/// (`replaceAll(RegExp(r'[^\d]'), '')`) — voir aussi [parseAmountInput].
class AmountInputFormatter extends TextInputFormatter {
  const AmountInputFormatter();

  /// Évite un dépassement de `double` / des montants absurdes collés depuis
  /// le presse-papiers (12 chiffres = 999 milliards FCFA).
  static const int maxDigits = 12;

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;
    final cursor = newValue.selection.isValid
        ? newValue.selection.extentOffset.clamp(0, raw.length)
        : raw.length;

    // Nombre de chiffres avant le curseur — c'est ce qu'on préserve.
    var digitsBeforeCursor = 0;
    for (var i = 0; i < cursor; i++) {
      if (_isDigit(raw.codeUnitAt(i))) digitsBeforeCursor++;
    }

    var digits = raw.replaceAll(RegExp(r'[^\d]'), '');
    // Pas de zéros de tête (« 0005 » → « 5 »), mais « 0 » seul reste.
    final trimmed = digits.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    digitsBeforeCursor -= digits.length - trimmed.length;
    digits = trimmed;
    if (digits.length > maxDigits) return oldValue;
    if (digitsBeforeCursor < 0) digitsBeforeCursor = 0;
    if (digitsBeforeCursor > digits.length) digitsBeforeCursor = digits.length;

    final buf = StringBuffer();
    var newCursor = 0;
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
      buf.write(digits[i]);
      if (i + 1 == digitsBeforeCursor) newCursor = buf.length;
    }
    final text = buf.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
}

/// Relit un montant saisi (avec ou sans séparateurs). `null` si vide.
double? parseAmountInput(String text) =>
    double.tryParse(text.replaceAll(RegExp(r'[^\d]'), ''));

/// Pré-remplit un champ montant déjà groupé (« 1 500 000 »).
String formatAmountInput(num value) {
  final digits = value.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return buf.toString();
}
