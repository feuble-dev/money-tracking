import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/categories/category_repository.dart';
import 'package:moneytracking/core/categories/expense_category.dart';
import 'package:moneytracking/core/database/database_helper.dart';

/// Couvre le socle « motif de dépense » (DB v15) : seed du catalogue,
/// règles d'auto-catégorisation, et déduction automatique côté pipeline SMS.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  // Fichier dédié : `flutter test` lance les fichiers de test en parallèle
  // et plusieurs touchent DatabaseHelper — un nom partagé les ferait se
  // supprimer mutuellement la base sur disque.
  DatabaseHelper.debugDatabaseName = 'moneytracking_categories_test.db';

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory
        .deleteDatabase(join(dir, DatabaseHelper.debugDatabaseName));
  });

  test('création v15 seede le catalogue de catégories par défaut', () async {
    final all = await CategoryRepository.getAll(activeOnly: false);
    expect(all.length, kDefaultExpenseCategories.length);
    expect(all.any((c) => c.code == 'alimentation'), isTrue);
    expect(all.any((c) => c.code == kCategoryOther), isTrue);

    final outOnly = await CategoryRepository.getAll(direction: 'out');
    expect(outOnly.every((c) => c.direction == 'out' || c.direction == 'both'),
        isTrue);
    expect(outOnly.any((c) => c.code == 'salaire'), isFalse); // 'in'
  });

  test('autoCategoryFor : crédit téléphone déduit du code de type', () async {
    final cat = await CategoryRepository.autoCategoryFor(
      transactionTypeCode: 'achat_credit',
      direction: 'out',
    );
    expect(cat, kCategoryCreditTel);
  });

  test('autoCategoryFor : règle sur le numéro puis sur le nom', () async {
    await CategoryRepository.upsertRule(
        matchType: 'phone', matchValue: '70112233', category: 'alimentation');
    await CategoryRepository.upsertRule(
        matchType: 'name', matchValue: 'sonabel', category: 'factures');

    expect(
      await CategoryRepository.autoCategoryFor(
          transactionTypeCode: 'transfert', clientPhone: '70112233'),
      'alimentation',
    );
    expect(
      await CategoryRepository.autoCategoryFor(
          transactionTypeCode: 'paiement_facture',
          clientName: 'Paiement SONABEL Ouaga'),
      'factures',
    );
    // Rien ne matche → null (reste « à catégoriser »).
    expect(
      await CategoryRepository.autoCategoryFor(
          transactionTypeCode: 'transfert', clientPhone: '76998877'),
      isNull,
    );
  });

  test('upsertRule est idempotent sur (match_type, match_value)', () async {
    await CategoryRepository.upsertRule(
        matchType: 'phone', matchValue: '70000000', category: 'transport');
    await CategoryRepository.upsertRule(
        matchType: 'phone', matchValue: '70000000', category: 'sante');
    final rules = await CategoryRepository.getRules();
    expect(rules.where((r) => r['match_value'] == '70000000').length, 1);
    expect(rules.firstWhere((r) => r['match_value'] == '70000000')['category'],
        'sante');
  });

  test('setTransactionCategory range la transaction et mémorise la règle',
      () async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('operators', {
      'id': 'op1',
      'name': 'Orange Money',
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    await db.insert('transactions', {
      'id': 'tx1',
      'operator_id': 'op1',
      'transaction_type': 'transfert',
      'direction': 'out',
      'amount': 5000,
      'client_phone': '70123456',
      'client_name': 'Boutique Chez Awa',
      'status': 'completed',
      'source': 'sms_auto',
      'created_at': DateTime.now().toIso8601String(),
    });

    expect(await CategoryRepository.uncategorizedCount(), 1);

    await CategoryRepository.setTransactionCategory(
      'tx1',
      category: 'courses',
      note: 'savon + huile',
      rememberFor: (matchType: 'name', matchValue: 'Boutique Chez Awa'),
    );

    final row = (await db.query('transactions', where: 'id = ?', whereArgs: ['tx1'])).first;
    expect(row['category'], 'courses');
    expect(row['note'], 'savon + huile');
    expect(await CategoryRepository.uncategorizedCount(), 0);

    // La règle mémorisée reclasse un futur paiement du même bénéficiaire.
    expect(
      await CategoryRepository.autoCategoryFor(
          transactionTypeCode: 'transfert',
          clientName: 'boutique chez awa'),
      'courses',
    );
  });

  test('budgets : set / get / suppression via montant nul', () async {
    await CategoryRepository.setBudget('alimentation', 50000);
    expect((await CategoryRepository.getBudgets())['alimentation'], 50000);
    await CategoryRepository.setBudget('alimentation', 0);
    expect((await CategoryRepository.getBudgets()).containsKey('alimentation'),
        isFalse);
  });
}
