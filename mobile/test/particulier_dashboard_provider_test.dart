import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/database/database_helper.dart';
import 'package:moneytracking/features/dashboard/providers/particulier_dashboard_provider.dart';

/// Vérifie l'agrégation du tableau de bord Particulier : totaux
/// entrées/sorties, dépenses par motif (dont « non catégorisé »), et top
/// bénéficiaires.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.debugDatabaseName = 'moneytracking_pdash_test.db';

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory
        .deleteDatabase(join(dir, DatabaseHelper.debugDatabaseName));

    final db = await DatabaseHelper.instance.database;
    await db.insert('operators', {
      'id': 'op1',
      'name': 'Orange Money',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    final now = DateTime.now();
    Future<void> tx(String id, String dir, double amount,
        {String? cat, String name = 'Awa', String phone = '70000001'}) {
      return db.insert('transactions', {
        'id': id,
        'operator_id': 'op1',
        'transaction_type': dir == 'in' ? 'transfert' : 'paiement_marchand',
        'direction': dir,
        'amount': amount,
        'client_phone': phone,
        'client_name': name,
        'category': cat,
        'status': 'completed',
        'source': 'sms_auto',
        'created_at': now.subtract(const Duration(days: 1)).toIso8601String(),
      });
    }

    await tx('t1', 'out', 5000, cat: 'alimentation', name: 'Marché Awa');
    await tx('t2', 'out', 4000, cat: 'alimentation', name: 'Marché Awa');
    await tx('t3', 'out', 8000, cat: 'transport', name: 'Station', phone: '70000002');
    await tx('t4', 'out', 2000, name: 'Inconnu', phone: '70000003'); // non catégorisé
    await tx('t5', 'in', 100000, cat: 'salaire', name: 'Employeur', phone: '70000009');
  });

  test('totaux, motifs et bénéficiaires', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final stats =
        await container.read(particulierDashboardProvider(null).future);

    expect(stats.totalIn, 100000);
    expect(stats.totalOut, 19000);
    expect(stats.txCountOut, 4);
    expect(stats.net, 81000);

    final byCat = {for (final c in stats.byCategory) c.code: c.amount};
    expect(byCat['alimentation'], 9000);
    expect(byCat['transport'], 8000);
    expect(byCat[kUncategorizedBucket], 2000);
    expect(stats.uncategorizedOut, 2000);

    // Premier bénéficiaire = plus gros cumul de dépenses.
    expect(stats.topBeneficiaries.first.label, 'Marché Awa');
    expect(stats.topBeneficiaries.first.amount, 9000);
    expect(stats.topBeneficiaries.first.count, 2);
  });
}
