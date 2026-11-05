import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/database/database_helper.dart';
import 'package:moneytracking/features/caisse/data/cash_closing_repository.dart';

/// Clôture de caisse : espèces attendues, écart, départ du lendemain.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.debugDatabaseName = 'moneytracking_closing_test.db';

  final day = DateTime(2026, 11, 3);
  var n = 0;

  Future<void> tx(String direction, double amount, {String status = 'completed', int hour = 10}) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('transactions', {
      'id': 't${n++}', 'operator_id': 'om', 'transaction_type': 'x', 'direction': direction,
      'amount': amount, 'commission': amount / 200, 'client_phone': '70000000',
      'status': status, 'source': 'sms_auto',
      'created_at': day.add(Duration(hours: hour)).toIso8601String(),
    });
  }

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(join(dir, DatabaseHelper.debugDatabaseName));
    final db = await DatabaseHelper.instance.database;
    await db.insert('operators', {'id': 'om', 'name': 'Orange Money', 'is_active': 1});
  });

  test('dépôts font entrer des espèces, retraits en font sortir', () async {
    await tx('in', 50000);
    await tx('in', 20000);
    await tx('out', 30000);
    await tx('out', 99999, status: 'cancelled');
    await tx('in', 1000, hour: 30); // lendemain
    final s = await CashClosingRepository.summarize(day);
    expect(s.operations, 3);
    expect(s.totalIn, 70000);
    expect(s.totalOut, 30000);
    expect(s.commissions, 500);
    expect(s.expected(100000), 140000);
  });

  test('écart, remplacement de la clôture, départ suggéré du lendemain', () async {
    await tx('in', 10000);
    expect(await CashClosingRepository.suggestedOpening(day), 0);
    var c = await CashClosingRepository.save(day: day, opening: 50000, counted: 58000);
    expect(c.expected, 60000);
    expect(c.gap, -2000);
    c = await CashClosingRepository.save(day: day, opening: 50000, counted: 60000, note: 'recompté');
    expect(c.gap, 0);
    expect((await CashClosingRepository.history()), hasLength(1));
    expect(await CashClosingRepository.suggestedOpening(day.add(const Duration(days: 1))), 60000);
  });
}
