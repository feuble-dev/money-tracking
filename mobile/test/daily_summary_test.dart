import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/database/database_helper.dart';
import 'package:moneytracking/core/summary/daily_summary_service.dart';

/// Bilan de la veille (compte Agence).
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.debugDatabaseName = 'moneytracking_daily_test.db';

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory
        .deleteDatabase(join(dir, DatabaseHelper.debugDatabaseName));
    final db = await DatabaseHelper.instance.database;
    await db.insert('operators', {'id': 'om', 'name': 'Orange Money', 'is_active': 1});
  });

  var n = 0;
  Future<void> tx(DateTime at, double amount, double commission, {String status = 'completed'}) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('transactions', {
      'id': 't${n++}', 'operator_id': 'om', 'transaction_type': 'depot',
      'direction': 'in', 'amount': amount, 'commission': commission,
      'client_phone': '70000000', 'status': status, 'source': 'sms_auto',
      'created_at': at.toIso8601String(),
    });
  }

  final day = DateTime(2026, 10, 27);

  test('totaux du jour et comparaison au même jour de la semaine précédente', () async {
    await tx(day.add(const Duration(hours: 9)), 50000, 250);
    await tx(day.add(const Duration(hours: 18)), 25000, 175);
    await tx(day.add(const Duration(hours: 19)), 10000, 50, status: 'cancelled');
    await tx(day.add(const Duration(days: 1, hours: 1)), 99999, 999); // lendemain
    await tx(day.subtract(const Duration(days: 7)).add(const Duration(hours: 10)), 40000, 200);

    final s = await DailySummaryService.summarize(await DatabaseHelper.instance.database, day);
    expect(s!.operations, 2);
    expect(s.volume, 75000);
    expect(s.commissions, 425);
    expect(s.commissionsWeekBefore, 200);
    expect(s.text, contains('2 opérations'));
    expect(s.text, contains('+113 %'));
  });

  test('journée sans activité : pas de bilan', () async {
    expect(await DailySummaryService.summarize(await DatabaseHelper.instance.database, day), isNull);
  });
}
