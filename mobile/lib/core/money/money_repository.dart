import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../categories/expense_category.dart';
import '../database/database_helper.dart';
import 'account_ref.dart';
import 'money_entry.dart';
import 'movement.dart';
import 'wallet.dart';

const _uuid = Uuid();

/// Accès aux comptes tenus à la main et à leurs opérations (DB v16).
/// Statique et sans dépendance Flutter/Riverpod, comme CategoryRepository :
/// utilisable depuis l'isolate SMS headless (rapprochement des virements).
class MoneyRepository {
  MoneyRepository._();

  /// Écart toléré entre un virement saisi et le SMS Mobile Money qui lui
  /// correspond (l'un peut précéder l'autre).
  static const linkWindow = Duration(days: 2);

  static Future<Database> get _db => DatabaseHelper.instance.database;

  // ---------------------------------------------------------------- Comptes

  /// Solde = solde initial + revenus − dépenses − virements sortants
  /// + virements entrants. Calculé en une requête, jamais stocké.
  static const _balanceSql = '''
    w.initial_balance
    + COALESCE((SELECT SUM(CASE e.kind WHEN 'income' THEN e.amount ELSE -e.amount END)
                FROM wallet_entries e WHERE e.account = 'wallet:' || w.id), 0)
    + COALESCE((SELECT SUM(e.amount) FROM wallet_entries e
                WHERE e.kind = 'transfer' AND e.counter_account = 'wallet:' || w.id), 0)
  ''';

  static Future<List<Wallet>> wallets({bool includeArchived = false}) async {
    final db = await _db;
    final rows = await db.rawQuery('''
      SELECT w.*, ($_balanceSql) AS balance
      FROM wallets w
      ${includeArchived ? '' : 'WHERE w.is_archived = 0'}
      ORDER BY w.sort_order, w.created_at
    ''');
    return rows.map(Wallet.fromMap).toList();
  }

  static Future<Wallet?> wallet(String id) async {
    final db = await _db;
    final rows = await db.rawQuery(
        'SELECT w.*, ($_balanceSql) AS balance FROM wallets w WHERE w.id = ?',
        [id]);
    return rows.isEmpty ? null : Wallet.fromMap(rows.first);
  }

  static Future<Wallet> createWallet({
    required String name,
    required WalletKind kind,
    double initialBalance = 0,
    String? icon,
    String? colorHex,
  }) async {
    final db = await _db;
    final order = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COALESCE(MAX(sort_order), 0) FROM wallets')) ??
        0;
    final w = Wallet(
      id: _uuid.v4(),
      name: name.trim(),
      kind: kind,
      icon: icon ?? kind.defaultIcon,
      colorHex: colorHex ?? kind.defaultColor,
      initialBalance: initialBalance,
      sortOrder: order + 1,
    );
    await db.insert('wallets',
        {...w.toMap(), 'created_at': DateTime.now().toIso8601String()});
    return w;
  }

  static Future<void> updateWallet(Wallet w) async {
    final db = await _db;
    await db.update('wallets', w.toMap(), where: 'id = ?', whereArgs: [w.id]);
  }

  /// Un compte avec historique est archivé (masqué, opérations conservées
  /// pour les statistiques) ; un compte vierge est supprimé.
  static Future<void> removeWallet(String id) async {
    final db = await _db;
    final ref = AccountRef.wallet(id).raw;
    final used = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM wallet_entries WHERE account = ? OR counter_account = ?',
            [ref, ref])) ??
        0;
    if (used > 0) {
      await db.update('wallets', {'is_archived': 1},
          where: 'id = ?', whereArgs: [id]);
    } else {
      await db.delete('wallets', where: 'id = ?', whereArgs: [id]);
    }
  }

  // ------------------------------------------------------------- Opérations

  static Future<MoneyEntry> addEntry({
    required EntryKind kind,
    required AccountRef account,
    required double amount,
    AccountRef? counterAccount,
    String? category,
    String? label,
    String? note,
    DateTime? occurredAt,
  }) async {
    assert(amount > 0);
    assert(kind != EntryKind.transfer || counterAccount != null);
    final now = DateTime.now();
    var entry = MoneyEntry(
      id: _uuid.v4(),
      kind: kind,
      account: account,
      counterAccount: kind == EntryKind.transfer ? counterAccount : null,
      amount: amount,
      category: kind == EntryKind.transfer ? kCategoryInternal : category,
      label: _clean(label),
      note: _clean(note),
      occurredAt: occurredAt ?? now,
    );
    final db = await _db;
    await db.transaction((txn) async {
      if (kind == EntryKind.transfer) {
        final linked = await _linkTransferToSms(txn, entry);
        if (linked != null) entry = entry.copyWith(linkedTransactionId: linked);
      }
      await txn.insert('wallet_entries', {
        ...entry.toMap(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });
    });
    return entry;
  }

  static Future<void> updateEntry(MoneyEntry entry) async {
    final db = await _db;
    await db.update(
      'wallet_entries',
      {...entry.toMap(), 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  static Future<void> deleteEntry(String id) async {
    final db = await _db;
    await db.delete('wallet_entries', where: 'id = ?', whereArgs: [id]);
  }

  static Future<MoneyEntry?> entry(String id) async {
    final db = await _db;
    final rows =
        await db.query('wallet_entries', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : MoneyEntry.fromMap(rows.first);
  }

  // -------------------------------------------------------------- Mouvements

  /// Fil chronologique : revenus/dépenses (Mobile Money + manuels, via
  /// `v_personal_flows`) et virements entre comptes. [account] restreint à
  /// un compte (y compris les virements qui le touchent).
  static Future<List<Movement>> movements({
    AccountRef? account,
    int limit = 60,
    DateTime? before,
  }) async {
    final db = await _db;
    final args = <Object?>[];
    String flowsWhere = '1=1';
    String transferWhere = "kind = 'transfer'";
    if (account != null) {
      flowsWhere += ' AND account = ?';
      args.add(account.raw);
    }
    if (before != null) {
      flowsWhere += ' AND occurred_at < ?';
      args.add(before.toIso8601String());
    }
    if (account != null) {
      transferWhere += ' AND (account = ? OR counter_account = ?)';
      args.addAll([account.raw, account.raw]);
    }
    if (before != null) {
      transferWhere += ' AND occurred_at < ?';
      args.add(before.toIso8601String());
    }
    args.add(limit);
    final rows = await db.rawQuery('''
      SELECT id, source, account, NULL AS counter_account, direction, amount,
             category, label, note, occurred_at
      FROM v_personal_flows WHERE $flowsWhere
      UNION ALL
      SELECT id, 'manual', account, counter_account, 'transfer', amount,
             category, label, note, occurred_at
      FROM wallet_entries WHERE $transferWhere
      ORDER BY occurred_at DESC
      LIMIT ?
    ''', args);
    return rows.map(Movement.fromMap).toList();
  }

  // ------------------------------------------- Rapprochement avec les SMS

  /// Virement saisi qui touche un portefeuille Mobile Money (ex. « retrait
  /// Orange Money → espèces ») : on cherche le SMS de cette opération, et on
  /// le range dans « Entre mes comptes » pour qu'il ne compte ni comme une
  /// dépense ni comme un revenu (sinon l'argent serait compté deux fois).
  static Future<String?> _linkTransferToSms(
      DatabaseExecutor db, MoneyEntry entry) async {
    final AccountRef momo;
    final String direction;
    if (entry.account.isMobileMoney) {
      momo = entry.account; // l'argent SORT du Mobile Money
      direction = 'out';
    } else if (entry.counterAccount?.isMobileMoney ?? false) {
      momo = entry.counterAccount!; // l'argent ENTRE dans le Mobile Money
      direction = 'in';
    } else {
      return null;
    }
    final from = entry.occurredAt.subtract(linkWindow).toIso8601String();
    final to = entry.occurredAt.add(linkWindow).toIso8601String();
    final rows = await db.rawQuery('''
      SELECT t.id FROM transactions t
      WHERE t.operator_id = ? AND t.direction = ? AND t.status = 'completed'
        AND ABS(t.amount - ?) < 0.5
        AND t.created_at BETWEEN ? AND ?
        AND COALESCE(t.category, '') IN ('', ?)
        AND NOT EXISTS (SELECT 1 FROM wallet_entries e
                        WHERE e.linked_transaction_id = t.id)
      ORDER BY ABS(julianday(t.created_at) - julianday(?))
      LIMIT 1
    ''', [
      momo.id, direction, entry.amount, from, to, kCategoryInternal,
      entry.occurredAt.toIso8601String(),
    ]);
    if (rows.isEmpty) return null;
    final txId = rows.first['id'] as String;
    await db.update('transactions', {'category': kCategoryInternal},
        where: 'id = ?', whereArgs: [txId]);
    return txId;
  }

  /// Côté pipeline SMS : la transaction Mobile Money qui arrive correspond
  /// à un virement déjà saisi (même opérateur, même montant, sens cohérent,
  /// dans la fenêtre) ? Si oui, on les rattache et la transaction doit être
  /// rangée dans « Entre mes comptes ».
  static Future<bool> claimTransferForSms({
    required String transactionId,
    required String operatorId,
    required String direction,
    required double amount,
    required DateTime at,
  }) async {
    final db = await _db;
    final momo = AccountRef.momo(operatorId).raw;
    final column = direction == 'out' ? 'account' : 'counter_account';
    final from = at.subtract(linkWindow).toIso8601String();
    final to = at.add(linkWindow).toIso8601String();
    final rows = await db.rawQuery('''
      SELECT id FROM wallet_entries
      WHERE kind = 'transfer' AND $column = ? AND linked_transaction_id IS NULL
        AND ABS(amount - ?) < 0.5 AND occurred_at BETWEEN ? AND ?
      ORDER BY ABS(julianday(occurred_at) - julianday(?))
      LIMIT 1
    ''', [momo, amount, from, to, at.toIso8601String()]);
    if (rows.isEmpty) return false;
    final claimed = await db.update(
      'wallet_entries',
      {'linked_transaction_id': transactionId},
      where: 'id = ? AND linked_transaction_id IS NULL',
      whereArgs: [rows.first['id']],
    );
    return claimed == 1;
  }

  static String? _clean(String? v) {
    final t = v?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }
}
