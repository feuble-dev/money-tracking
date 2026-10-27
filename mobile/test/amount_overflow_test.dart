import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:moneytracking/core/format/amount_input_formatter.dart';
import 'package:moneytracking/core/format/formats.dart';
import 'package:moneytracking/features/dashboard/widgets/pie_chart_widget.dart';
import 'package:moneytracking/features/dashboard/widgets/ratio_chart_widget.dart';
import 'package:moneytracking/shared/widgets/amount_text.dart';

/// Gros montants sur petit écran : aucun « RenderFlex overflowed » ne doit
/// être levé (le test échoue sur toute exception de rendu).
void main() {
  setUpAll(() => initializeDateFormatting('fr_FR'));

  Future<void> pumpNarrow(WidgetTester tester, Widget child,
      {double width = 300, double height = 600}) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: child),
    ));
    await tester.pump();
  }

  group('AmountText', () {
    testWidgets('un montant énorme dans une Row ne déborde pas',
        (tester) async {
      await pumpNarrow(
        tester,
        Row(children: [
          const Expanded(child: Text('Solde opérateur', maxLines: 1)),
          Flexible(
            child: AmountText(AppFormats.fcfa(987654321012),
                style: const TextStyle(fontSize: 28)),
          ),
        ]),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(AmountText), findsOneWidget);
    });

    testWidgets('reste sur une seule ligne', (tester) async {
      await pumpNarrow(
        tester,
        SizedBox(
          width: 120,
          child: AmountText(AppFormats.fcfa(123456789),
              style: const TextStyle(fontSize: 26)),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text));
      expect(text.maxLines, 1);
      expect(text.softWrap, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('Graphiques du tableau de bord', () {
    testWidgets('ratio entrées/sorties avec des milliards', (tester) async {
      await pumpNarrow(
        tester,
        const SizedBox(
          height: 180,
          child: RatioChartWidget(
              deposits: 125000000000, withdrawals: 98000000000),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('répartition avec beaucoup d\'opérateurs', (tester) async {
      await pumpNarrow(
        tester,
        SizedBox(
          height: 220,
          child: PieChartWidget(data: [
            for (var i = 0; i < 9; i++)
              {'name': 'Opérateur numéro $i', 'total': 1234567890.0 * (i + 1)},
          ]),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AmountInputFormatter', () {
    const f = AmountInputFormatter();
    TextEditingValue type(String text, [int? cursor]) => f.formatEditUpdate(
          TextEditingValue.empty,
          TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: cursor ?? text.length),
          ),
        );

    test('groupe par milliers', () {
      expect(type('1500000').text, '1 500 000');
      expect(type('999').text, '999');
      expect(type('1000').text, '1 000');
    });

    test('ignore les caractères non numériques et les zéros de tête', () {
      expect(type('00 12a3,4').text, '1 234');
      expect(type('0').text, '0');
      expect(type('').text, '');
    });

    test('le curseur reste après le même chiffre', () {
      // « 1 000 » puis on tape « 5 » entre le 1 et les zéros → « 15000 ».
      final v = type('15 000', 2);
      expect(v.text, '15 000');
      expect(v.selection.baseOffset, 2);
      // Curseur à la fin par défaut.
      final w = type('12345');
      expect(w.text, '12 345');
      expect(w.selection.baseOffset, w.text.length);
    });

    test('refuse au-delà de 12 chiffres', () {
      const old = TextEditingValue(text: '999 999 999 999');
      final v = f.formatEditUpdate(
          old, const TextEditingValue(text: '9999999999999'));
      expect(v, old);
    });

    test('relecture / pré-remplissage', () {
      expect(parseAmountInput('1 500 000'), 1500000);
      expect(parseAmountInput(''), isNull);
      expect(formatAmountInput(2500000.0), '2 500 000');
    });
  });
}
