import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracking/core/security/pin_service.dart';

/// Vérifie la dérivation PBKDF2 du PIN et la migration transparente depuis
/// l'ancien format SHA-256 brut.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('setPin stocke un hash PBKDF2 salé, jamais le PIN en clair', () async {
    final svc = PinService();
    await svc.setPin('1234');

    const storage = FlutterSecureStorage();
    final stored = await storage.read(key: 'moneytracking_pin_hash');
    expect(stored, isNotNull);
    expect(stored!.startsWith('pbkdf2\$20000\$'), isTrue);
    expect(stored.contains('1234'), isFalse);
    expect(await svc.isPinSet(), isTrue);
  });

  test('verifyPin : vrai pour le bon PIN, faux sinon', () async {
    final svc = PinService();
    await svc.setPin('4271');
    expect(await svc.verifyPin('4271'), isTrue);
    expect(await svc.verifyPin('4270'), isFalse);
    expect(await svc.verifyPin('00000'), isFalse);
  });

  test('deux setPin du même PIN → sels différents', () async {
    final svc = PinService();
    await svc.setPin('1111');
    const storage = FlutterSecureStorage();
    final a = await storage.read(key: 'moneytracking_pin_hash');
    await svc.setPin('1111');
    final b = await storage.read(key: 'moneytracking_pin_hash');
    expect(a, isNot(equals(b)));
  });

  test('migration : ancien hash SHA-256 brut vérifié puis ré-encodé', () async {
    // Simule une install pré-migration.
    final legacy = sha256.convert(utf8.encode('9999')).toString();
    FlutterSecureStorage.setMockInitialValues({
      'moneytracking_pin_hash': legacy,
      'moneytracking_pin_set': 'true',
    });

    final svc = PinService();
    expect(await svc.verifyPin('9999'), isTrue);

    const storage = FlutterSecureStorage();
    final upgraded = await storage.read(key: 'moneytracking_pin_hash');
    expect(upgraded!.startsWith('pbkdf2\$'), isTrue);
    // Toujours valide après ré-encodage.
    expect(await svc.verifyPin('9999'), isTrue);
    expect(await svc.verifyPin('1234'), isFalse);
  });

  test('blocage progressif après 5 erreurs, levé par le bon PIN', () async {
    final svc = PinService();
    await svc.setPin('2580');
    for (var i = 0; i < PinService.freeAttempts - 1; i++) {
      expect(await svc.verifyPin('0000'), isFalse);
      expect(await svc.lockRemaining(), Duration.zero);
    }
    expect(await svc.verifyPin('0000'), isFalse); // 5e erreur → bloqué
    expect(await svc.lockRemaining(), greaterThan(Duration.zero));
    // Pendant le blocage, même le bon PIN est refusé.
    expect(await svc.verifyPin('2580'), isFalse);
  });

  test('durées de blocage : 30 s puis doublées, max 15 min', () {
    expect(PinService.lockoutFor(4), Duration.zero);
    expect(PinService.lockoutFor(5), const Duration(seconds: 30));
    expect(PinService.lockoutFor(6), const Duration(seconds: 60));
    expect(PinService.lockoutFor(20), const Duration(minutes: 15));
  });

  test('un succès remet le compteur à zéro', () async {
    final svc = PinService();
    await svc.setPin('2580');
    for (var i = 0; i < PinService.freeAttempts - 1; i++) {
      await svc.verifyPin('0000');
    }
    expect(await svc.verifyPin('2580'), isTrue);
    expect(await svc.verifyPin('0000'), isFalse);
    expect(await svc.lockRemaining(), Duration.zero);
  });
}
