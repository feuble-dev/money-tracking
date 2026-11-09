import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/database/caisse_repository.dart';
import 'package:moneytracking/core/database/database_helper.dart';

/// Alerte de float : signalée au franchissement du seuil, une seule fois.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.debugDatabaseName = 'moneytracking_float_test.db';

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory
        .deleteDatabase(join(dir, DatabaseHelper.debugDatabaseName));
    final db = await DatabaseHelper.instance.database;
    await db.insert('operators', {'id': 'om', 'name': 'Orange Money', 'is_active': 1});
    await db.insert('caisse', {
      'id': 'c1', 'operator_id': 'om', 'solde_initial': 120000,
      'solde_actuel': 120000, 'seuil_alerte': 100000,
      'updated_at': DateTime.now().toIso8601String(),
    });
  });

  Future<FloatAlert?> sms(double soldeApres, int minute) =>
      CaisseRepository.updateSoldeAfterTransaction(
        operatorId: 'om', amount: 10000, direction: 'in',
        soldeApres: soldeApres, transactionAt: DateTime(2026, 10, 1, 9, minute),
      );

  test('alerte au passage sous le seuil, puis plus tant qu\'il reste dessous', () async {
    expect(await sms(110000, 1), isNull);
    final alert = await sms(95000, 2);
    expect(alert, isNotNull);
    expect(alert!.solde, 95000);
    expect(alert.seuil, 100000);
    expect(await sms(80000, 3), isNull);
    // Rechargement puis nouveau passage : nouvelle alerte.
    expect(await sms(150000, 4), isNull);
    expect(await sms(90000, 5), isNotNull);
  });

  test('sans seuil configuré, jamais d\'alerte', () async {
    final db = await DatabaseHelper.instance.database;
    await db.update('caisse', {'seuil_alerte': 0});
    expect(await sms(10, 1), isNull);
  });

  test('transaction manuelle (delta) : alerte aussi', () async {
    final alert = await CaisseRepository.updateSoldeAfterTransaction(
      operatorId: 'om', amount: 30000, direction: 'in');
    expect(alert?.solde, 90000);
  });
}
