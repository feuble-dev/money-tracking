import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:moneytracking/core/categories/expense_category.dart';
import 'package:moneytracking/core/database/database_helper.dart';
import 'package:moneytracking/core/money/account_ref.dart';
import 'package:moneytracking/core/money/money_entry.dart';
import 'package:moneytracking/core/money/money_repository.dart';
import 'package:moneytracking/core/money/wallet.dart';

/// « Tout mon argent » (DB v16) : comptes manuels, soldes calculés, vue des
/// flux réels, rapprochement virement ↔ SMS Mobile Money.
void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  DatabaseHelper.debugDatabaseName = 'moneytracking_money_test.db';

  setUp(() async {
    await DatabaseHelper.instance.close();
    final dir = await databaseFactory.getDatabasesPath();
    await databaseFactory
        .deleteDatabase(join(dir, DatabaseHelper.debugDatabaseName));
    final db = await DatabaseHelper.instance.database;
    await db.insert('operators', {
      'id': 'om', 'name': 'Orange Money', 'is_active': 1,
    });
  });

  Future<void> momoTx(String id, String direction, double amount,
      {String? category, DateTime? at}) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('transactions', {
      'id': id, 'operator_id': 'om', 'transaction_type': 'x',
      'direction': direction, 'amount': amount, 'commission': 0,
      'client_phone': '70000000', 'status': 'completed', 'source': 'sms_auto',
      'category': category,
      'created_at': (at ?? DateTime.now()).toIso8601String(),
    });
  }

  test('un compte « Espèces » existe d\'office', () async {
    final w = await MoneyRepository.wallets();
    expect(w.single.kind, WalletKind.cash);
    expect(w.single.balance, 0);
  });

  test('solde calculé : initial + revenus − dépenses ± virements', () async {
    final cash = (await MoneyRepository.wallets()).single;
    final bank = await MoneyRepository.createWallet(
        name: 'Coris Bank', kind: WalletKind.bank, initialBalance: 100000);

    await MoneyRepository.addEntry(
        kind: EntryKind.income, account: cash.ref, amount: 50000,
        category: 'salaire');
    await MoneyRepository.addEntry(
        kind: EntryKind.expense, account: cash.ref, amount: 7500,
        category: 'alimentation', label: 'Marché');
    await MoneyRepository.addEntry(
        kind: EntryKind.transfer, account: bank.ref,
        counterAccount: cash.ref, amount: 20000);

    final byId = {for (final w in await MoneyRepository.wallets()) w.id: w};
    expect(byId[cash.id]!.balance, 50000 - 7500 + 20000);
    expect(byId[bank.id]!.balance, 100000 - 20000);
  });

  test('vue des flux : manuels + Mobile Money, sans les virements', () async {
    final cash = (await MoneyRepository.wallets()).single;
    await momoTx('t1', 'out', 3000, category: 'transport');
    await MoneyRepository.addEntry(
        kind: EntryKind.expense, account: cash.ref, amount: 2000,
        category: 'alimentation');
    await MoneyRepository.addEntry(
        kind: EntryKind.transfer, account: const AccountRef.momo('om'),
        counterAccount: cash.ref, amount: 10000);

    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery(
        "SELECT SUM(amount) AS s FROM v_personal_flows WHERE direction='out'");
    expect(rows.first['s'], 5000);

    final moves = await MoneyRepository.movements();
    expect(moves.length, 3);
    expect(moves.where((m) => m.isTransfer).length, 1);
  });

  test('virement saisi APRÈS le SMS : le SMS passe en « Entre mes comptes »',
      () async {
    final cash = (await MoneyRepository.wallets()).single;
    await momoTx('retrait', 'out', 10000);
    final e = await MoneyRepository.addEntry(
        kind: EntryKind.transfer, account: const AccountRef.momo('om'),
        counterAccount: cash.ref, amount: 10000);
    expect(e.linkedTransactionId, 'retrait');

    final db = await DatabaseHelper.instance.database;
    final tx = await db.query('transactions', where: "id='retrait'");
    expect(tx.single['category'], kCategoryInternal);
    final out = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM v_personal_flows WHERE direction='out'");
    expect(out.first['c'], 0); // pas compté comme une dépense
  });

  test('virement saisi AVANT le SMS : le pipeline le reconnaît', () async {
    final cash = (await MoneyRepository.wallets()).single;
    await MoneyRepository.addEntry(
        kind: EntryKind.transfer, account: cash.ref,
        counterAccount: const AccountRef.momo('om'), amount: 25000);
    // Dépôt d'espèces sur Orange Money → SMS « in » de 25 000.
    expect(
      await MoneyRepository.claimTransferForSms(
          transactionId: 'depot', operatorId: 'om', direction: 'in',
          amount: 25000, at: DateTime.now()),
      isTrue,
    );
    // Un second SMS identique ne peut pas réclamer le même virement.
    expect(
      await MoneyRepository.claimTransferForSms(
          transactionId: 'depot2', operatorId: 'om', direction: 'in',
          amount: 25000, at: DateTime.now()),
      isFalse,
    );
    // Mauvais sens : rien.
    expect(
      await MoneyRepository.claimTransferForSms(
          transactionId: 'x', operatorId: 'om', direction: 'out',
          amount: 25000, at: DateTime.now()),
      isFalse,
    );
  });

  test('compte avec historique archivé, compte vierge supprimé', () async {
    final a = await MoneyRepository.createWallet(
        name: 'Tontine', kind: WalletKind.savings);
    final b = await MoneyRepository.createWallet(
        name: 'Vide', kind: WalletKind.other);
    await MoneyRepository.addEntry(
        kind: EntryKind.income, account: a.ref, amount: 5000);
    await MoneyRepository.removeWallet(a.id);
    await MoneyRepository.removeWallet(b.id);
    final all = await MoneyRepository.wallets(includeArchived: true);
    expect(all.any((w) => w.id == a.id && w.isArchived), isTrue);
    expect(all.any((w) => w.id == b.id), isFalse);
  });
}
