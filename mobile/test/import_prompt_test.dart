import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/database/database_helper.dart';
import 'package:moneytracking/core/historique/import_prompt.dart';

/// Proposition d'import des anciens SMS : à chaque ouverture tant que ce
/// n'est pas fait.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.debugDatabaseName = 'moneytracking_import_prompt_test.db';

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(join(dir, DatabaseHelper.debugDatabaseName));
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
  });

  test('demandé à chaque ouverture tant que rien n\'est importé', () async {
    expect(await ImportPrompt.shouldAsk(hasSmsPermission: true), isTrue);
    expect(await ImportPrompt.shouldAsk(hasSmsPermission: true), isTrue);
  });

  test('pas demandé sans accès aux SMS ni avant la fin de l\'inscription', () async {
    expect(await ImportPrompt.shouldAsk(hasSmsPermission: false), isFalse);
    SharedPreferences.setMockInitialValues({});
    expect(await ImportPrompt.shouldAsk(hasSmsPermission: true), isFalse);
  });

  test('plus demandé après un import ou « ne plus demander »', () async {
    await ImportPrompt.markDone();
    expect(await ImportPrompt.shouldAsk(hasSmsPermission: true), isFalse);
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    await ImportPrompt.neverAskAgain();
    expect(await ImportPrompt.shouldAsk(hasSmsPermission: true), isFalse);
  });

  test('installation qui a déjà importé avant cette fonctionnalité', () async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('operators', {'id': 'om', 'name': 'Orange Money', 'is_active': 1});
    await db.insert('transactions', {
      'id': 't1', 'operator_id': 'om', 'transaction_type': 'x', 'direction': 'in',
      'amount': 1000, 'commission': 0, 'client_phone': '70000000', 'status': 'completed',
      'source': 'sms_import', 'created_at': DateTime(2026, 1, 1).toIso8601String(),
    });
    expect(await ImportPrompt.shouldAsk(hasSmsPermission: true), isFalse);
    // Mémorisé : plus de requête la fois suivante.
    expect((await SharedPreferences.getInstance()).getBool('history_import_done'), isTrue);
  });
}
