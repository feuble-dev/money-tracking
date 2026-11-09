import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/database/database_helper.dart';
import 'package:moneytracking/core/sync/sync_service.dart';

/// Synchro patron : les lignes modifiées après leur premier envoi
/// (transaction annulée, client renommé) repartent au push suivant.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.debugDatabaseName = 'moneytracking_sync_test.db';

  late Database db;

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory.deleteDatabase(join(dir, DatabaseHelper.debugDatabaseName));
    db = await DatabaseHelper.instance.database;
    await db.insert('operators', {'id': 'om', 'name': 'Orange Money', 'is_active': 1});
    await db.insert('agences', {'id': 'ag', 'nom': 'Tampouy', 'backend_agence_id': 1});
    for (final id in ['t1', 't2']) {
      await db.insert('transactions', {
        'id': id, 'operator_id': 'om', 'transaction_type': 'depot', 'direction': 'in',
        'amount': 5000, 'commission': 25, 'client_phone': '70000000',
        'status': 'completed', 'source': 'sms_auto', 'agence_id': 'ag',
        'created_at': DateTime(2026, 11, 1).toIso8601String(),
      });
    }
    await db.insert('clients', {
      'id': 'c1', 'first_name': 'Awa', 'last_name': 'Zongo',
      'phone_number': '70000000', 'agence_id': 'ag',
    });
  });

  test('premier envoi : tout ; ensuite : rien tant que rien ne change', () async {
    final first = await SyncService.pending(db, 'ag', {});
    expect(first.transactions.map((t) => t['id']), ['t1', 't2']);
    expect(first.clients, hasLength(1));
    final again = await SyncService.pending(db, 'ag', first.cursors);
    expect(again.isEmpty, isTrue);
  });

  test('une transaction annulée après envoi est renvoyée avec son statut', () async {
    final first = await SyncService.pending(db, 'ag', {});
    await db.update('transactions', {'status': 'cancelled'}, where: 'id = ?', whereArgs: ['t2']);
    await db.update('clients', {'first_name': 'Aminata'}, where: 'id = ?', whereArgs: ['c1']);

    final next = await SyncService.pending(db, 'ag', first.cursors);
    expect(next.transactions.map((t) => t['id']), ['t2']);
    expect(next.transactions.single['status'], 'cancelled');
    expect(next.clients.single['first_name'], 'Aminata');
    expect((await SyncService.pending(db, 'ag', next.cursors)).isEmpty, isTrue);
  });

  test('une modification sans effet pour le patron ne déclenche rien', () async {
    final first = await SyncService.pending(db, 'ag', {});
    await db.update('transactions', {'note': 'vu'}, where: 'id = ?', whereArgs: ['t1']);
    expect((await SyncService.pending(db, 'ag', first.cursors)).isEmpty, isTrue);
  });

  test('nouvelle ligne modifiée avant son premier envoi : envoyée une fois', () async {
    final first = await SyncService.pending(db, 'ag', {});
    await db.insert('transactions', {
      'id': 't3', 'operator_id': 'om', 'transaction_type': 'depot', 'direction': 'in',
      'amount': 100, 'commission': 0, 'client_phone': '70000001', 'status': 'pending',
      'source': 'sms_auto', 'agence_id': 'ag', 'created_at': DateTime.now().toIso8601String(),
    });
    await db.update('transactions', {'status': 'completed'}, where: 'id = ?', whereArgs: ['t3']);
    final next = await SyncService.pending(db, 'ag', first.cursors);
    expect(next.transactions.map((t) => t['id']), ['t3']);
  });

  test('une ligne insérée sans agence est rattachée à l\'agence de l\'appareil', () async {
    // Le pipeline SMS, l'import et les recharges n'écrivent pas agence_id :
    // sans le trigger v18, rien de tout cela n'atteignait le patron.
    final first = await SyncService.pending(db, 'ag', {});
    await db.insert('transactions', {
      'id': 'sms1', 'operator_id': 'om', 'transaction_type': 'retrait', 'direction': 'out',
      'amount': 2000, 'commission': 10, 'client_phone': '70000002', 'status': 'completed',
      'source': 'sms_auto', 'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('caisse_operations', {
      'id': 'r1', 'operator_id': 'om', 'type': 'rechargement', 'montant': 100000,
      'created_at': DateTime.now().toIso8601String(),
    });
    final next = await SyncService.pending(db, 'ag', first.cursors);
    expect(next.transactions.map((t) => t['id']), ['sms1']);
    expect(next.caisseOps.map((o) => o['id']), ['r1']);
    // Le rattachement ne compte pas comme une modification à renvoyer.
    expect((await SyncService.pending(db, 'ag', next.cursors)).isEmpty, isTrue);
  });
}
