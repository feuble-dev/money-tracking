import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/database/database_helper.dart';
import 'package:moneytracking/features/transactions/providers/transaction_provider.dart';

/// Liste paginée : pages de 100, totaux sur tout le filtre.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.debugDatabaseName = 'moneytracking_pagination_test.db';

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(join(dir, DatabaseHelper.debugDatabaseName));
    final db = await DatabaseHelper.instance.database;
    await db.insert('operators', {'id': 'om', 'name': 'Orange Money', 'is_active': 1});
    final batch = db.batch();
    for (var i = 0; i < 250; i++) {
      batch.insert('transactions', {
        'id': 't$i', 'operator_id': 'om', 'transaction_type': 'x',
        'direction': i.isEven ? 'in' : 'out', 'amount': 1000, 'commission': 0,
        'client_phone': '70000000', 'status': i == 0 ? 'cancelled' : 'completed',
        'source': 'sms_auto',
        'created_at': DateTime(2026, 1, 1).add(Duration(minutes: i)).toIso8601String(),
      });
    }
    await batch.commit(noResult: true);
  });

  Future<TransactionPage> settle(ProviderContainer c) async {
    for (var i = 0; i < 50; i++) {
      final v = c.read(transactionsProvider).valueOrNull;
      if (v != null) return v;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    throw StateError('pas de données');
  }

  test('pages successives, totaux sur tout le filtre, plus récentes d\'abord', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    var page = await settle(c);
    expect(page.count, 249); // la transaction annulée est exclue
    expect(page.items, hasLength(kTransactionsPageSize));
    expect(page.items.first.id, 't249');
    expect(page.hasMore, isTrue);
    expect(page.totalIn, 124 * 1000);
    expect(page.totalOut, 125 * 1000);

    final notifier = c.read(transactionsProvider.notifier);
    await notifier.loadMore();
    await notifier.loadMore();
    page = c.read(transactionsProvider).value!;
    expect(page.items, hasLength(249));
    expect(page.items.map((t) => t.id).toSet(), hasLength(249));
    expect(page.hasMore, isFalse);
  });

  test('le filtre s\'applique aux totaux et aux pages', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await settle(c);
    c.read(transactionFilterProvider.notifier).state = const TransactionFilter(direction: 'out');
    await c.read(transactionsProvider.notifier).loadTransactions();
    final page = c.read(transactionsProvider).value!;
    expect(page.count, 125);
    expect(page.totalIn, 0);
    expect(page.items.every((t) => t.direction == 'out'), isTrue);
  });
}
