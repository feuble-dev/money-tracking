import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/database/database_helper.dart';
import 'package:moneytracking/features/commissions/data/commission_stats.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.debugDatabaseName = 'moneytracking_commission_test.db';

  final now = DateTime(2026, 11, 20, 18);
  var n = 0;

  Future<void> tx(DateTime at, String type, double amount, double commission,
      {String op = 'om', String status = 'completed'}) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('transactions', {
      'id': 't${n++}', 'operator_id': op, 'transaction_type': type, 'direction': 'in',
      'amount': amount, 'commission': commission, 'client_phone': '70000000',
      'status': status, 'source': 'sms_auto', 'created_at': at.toIso8601String(),
    });
  }

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(join(dir, DatabaseHelper.debugDatabaseName));
    final db = await DatabaseHelper.instance.database;
    await db.insert('operators', {'id': 'om', 'name': 'Orange Money', 'is_active': 1});
    await db.insert('operators', {'id': 'mv', 'name': 'Moov Money', 'is_active': 1});
    await tx(now.subtract(const Duration(hours: 2)), 'depot', 50000, 250);
    await tx(now.subtract(const Duration(hours: 1)), 'retrait', 20000, 300, op: 'mv');
    await tx(now.subtract(const Duration(hours: 1)), 'retrait', 9999, 999, status: 'cancelled');
    await tx(now.subtract(const Duration(days: 3)), 'retrait', 10000, 150);
    await tx(DateTime(2026, 10, 2), 'depot', 1000, 5);
  });

  test('la période pilote tous les chiffres', () async {
    final db = await DatabaseHelper.instance.database;
    final today = await loadCommissionStats(db, CommissionPeriod.today, now: now);
    expect(today.total, 550);
    expect(today.count, 2);
    expect(today.byService.first.label, 'retrait');
    expect(today.byOperator.firstWhere((o) => o.key == 'mv').commission, 300);

    final week = await loadCommissionStats(db, CommissionPeriod.week, now: now);
    expect(week.total, 700);
    expect(week.byService.first.commission, 450); // retraits
    expect((await loadCommissionStats(db, CommissionPeriod.all, now: now)).total, 705);
  });

  test('courbe des 14 jours : un point par jour, annulées exclues', () async {
    final db = await DatabaseHelper.instance.database;
    final s = await loadCommissionStats(db, CommissionPeriod.month, now: now);
    expect(s.last14Days, hasLength(14));
    expect(s.last14Days.last, 550);
    expect(s.last14Days[10], 150);
  });
}
