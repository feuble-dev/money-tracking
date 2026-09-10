import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/database/database_helper.dart';
import 'package:moneytracking/features/categories/providers/recurring_provider.dart';

/// Vérifie la détection des paiements récurrents : cadence régulière,
/// montants proches, motif dominant, et rejet des séries irrégulières.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.debugDatabaseName = 'moneytracking_recurring_test.db';

  late Database db;

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory
        .deleteDatabase(join(dir, DatabaseHelper.debugDatabaseName));
    db = await DatabaseHelper.instance.database;
    await db.insert('operators', {
      'id': 'op1',
      'name': 'Orange Money',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
  });

  Future<void> tx(String id, String name, double amount, DateTime at,
      {String? cat}) {
    return db.insert('transactions', {
      'id': id,
      'operator_id': 'op1',
      'transaction_type': 'transfert',
      'direction': 'out',
      'amount': amount,
      'client_phone': '70000001',
      'client_name': name,
      'category': cat,
      'status': 'completed',
      'source': 'sms_auto',
      'created_at': at.toIso8601String(),
    });
  }

  test('série mensuelle régulière détectée avec motif dominant', () async {
    final now = DateTime.now();
    await tx('a1', 'Proprio Maison', 50000,
        now.subtract(const Duration(days: 92)), cat: 'logement');
    await tx('a2', 'Proprio Maison', 50000,
        now.subtract(const Duration(days: 61)), cat: 'logement');
    await tx('a3', 'Proprio Maison', 52000,
        now.subtract(const Duration(days: 30)), cat: 'logement');
    // Une série "bruit" irrégulière — ne doit pas être retenue.
    await tx('b1', 'Boutique', 1500, now.subtract(const Duration(days: 80)));
    await tx('b2', 'Boutique', 1500, now.subtract(const Duration(days: 79)));
    await tx('b3', 'Boutique', 1500, now.subtract(const Duration(days: 2)));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final series =
        await container.read(recurringPaymentsProvider.future);

    expect(series.length, 1);
    final s = series.first;
    expect(s.label, 'Proprio Maison');
    expect(s.typicalAmount, 50000);
    expect(s.count, 3);
    expect(s.avgIntervalDays, inInclusiveRange(28, 33));
    expect(s.dominantCategory, 'logement');
  });

  test('moins de 3 occurrences → pas de série', () async {
    final now = DateTime.now();
    await tx('c1', 'Netflix', 4000, now.subtract(const Duration(days: 60)));
    await tx('c2', 'Netflix', 4000, now.subtract(const Duration(days: 30)));

    final container = ProviderContainer();
    addTearDown(container.dispose);
    final series = await container.read(recurringPaymentsProvider.future);
    expect(series, isEmpty);
  });
}
