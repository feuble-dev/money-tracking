import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/account/account_deletion.dart';
import 'package:moneytracking/core/database/database_helper.dart';

/// Suppression du compte : après l'effacement local, l'app repart vide.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.debugDatabaseName = 'moneytracking_account_deletion_test.db';

  // path_provider n'existe pas en test : pas de dossier de logos à effacer.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'), (_) async => null);

  test('efface la base, les préférences et le stockage sécurisé', () async {
    FlutterSecureStorage.setMockInitialValues({'pin_hash': 'x', 'device_token': 'y'});
    SharedPreferences.setMockInitialValues({'onboarding_complete': true, 'account_type': 'particulier'});
    final db = await DatabaseHelper.instance.database;
    await db.insert('wallets', {'id': 'w-test', 'name': 'Tontine', 'kind': 'cash', 'icon': 'x', 'color': 'x', 'created_at': DateTime.now().toIso8601String()});

    await AccountDeletion.wipeLocal();

    final path = join(await databaseFactory.getDatabasesPath(), DatabaseHelper.debugDatabaseName);
    expect(await databaseFactory.databaseExists(path), isFalse);
    expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    expect(await const FlutterSecureStorage().readAll(), isEmpty);

    // Réouverture : base neuve, sans les données d'avant.
    final fresh = await DatabaseHelper.instance.database;
    expect(await fresh.query('wallets', where: 'id = ?', whereArgs: ['w-test']), isEmpty);
    await DatabaseHelper.instance.deleteDatabaseFile();
  });
}
