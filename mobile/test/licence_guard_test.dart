import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moneytracking/core/licence/licence_guard.dart';

/// Un compte Particulier n'a aucun flux payant (ni licence, ni achat
/// d'historique SMS) — LicenceGuard.verifier doit autoriser toutes les
/// actions sans jamais consulter le statut de licence ni afficher de
/// dialog, quel que soit l'ActionType.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'compte Particulier : toutes les ActionType sont autorisées sans dialog',
      (tester) async {
    SharedPreferences.setMockInitialValues({'account_type': 'particulier'});

    late BuildContext ctx;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      }),
    ));

    for (final action in ActionType.values) {
      final autorise = await LicenceGuard.verifier(ctx, action);
      expect(autorise, isTrue, reason: 'ActionType.$action');
    }
    // Aucun dialog ne doit avoir été poussé par-dessus la page.
    await tester.pump();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
