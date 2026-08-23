import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';

const _uuid = Uuid();

/// Type de transaction attaché à un opérateur (jointure operator_transaction_types
/// x transaction_types), catalogue ou custom (D3) — c'est ce que l'agent choisit
/// quand il configure un pattern SMS pour cet opérateur.
class OperatorTransactionTypeOption {
  final String linkId; // operator_transaction_types.id
  final String transactionTypeId;
  final String code;
  final String label;
  final String defaultDirection; // 'in' | 'out'
  final bool isCustom;

  OperatorTransactionTypeOption({
    required this.linkId,
    required this.transactionTypeId,
    required this.code,
    required this.label,
    required this.defaultDirection,
    required this.isCustom,
  });
}

/// Types de transaction attachés à un opérateur donné, utilisés pour
/// alimenter le sélecteur de l'écran de configuration SMS.
final operatorTransactionTypesProvider = FutureProvider.family<
    List<OperatorTransactionTypeOption>, String>((ref, operatorId) async {
  final db = await DatabaseHelper.instance.database;
  final rows = await db.rawQuery('''
    SELECT ott.id as link_id, tt.id as type_id, tt.code, tt.label,
           tt.default_direction, tt.is_custom
    FROM operator_transaction_types ott
    JOIN transaction_types tt ON tt.id = ott.transaction_type_id
    WHERE ott.operator_id = ? AND ott.is_active = 1
    ORDER BY tt.label ASC
  ''', [operatorId]);
  return rows
      .map((r) => OperatorTransactionTypeOption(
            linkId: r['link_id'] as String,
            transactionTypeId: r['type_id'] as String,
            code: r['code'] as String,
            label: r['label'] as String,
            defaultDirection: r['default_direction'] as String,
            isCustom: (r['is_custom'] as int? ?? 0) == 1,
          ))
      .toList();
});

/// Crée un type de transaction custom (hors catalogue admin) et l'attache
/// immédiatement à l'opérateur — utilisé quand aucun type existant ne
/// convient (ex: un type propre à cet opérateur, non encore au catalogue).
class TransactionTypeRepository {
  /// Attache un type global déjà existant (ex: 'deposit'/'withdrawal',
  /// toujours seedés — voir DatabaseHelper._seedDefaultTransactionTypes) à
  /// un opérateur qui vient d'être créé, avec son USSD/commission propres à
  /// cette paire. Retourne l'id de la liaison (operator_transaction_types.id)
  /// à utiliser comme operator_transaction_type_id du pattern SMS associé.
  static Future<String> attachExistingTypeToOperator({
    required String operatorId,
    required String code,
    String? ussdCode,
    double commissionTaux = 0,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final type = (await db.query('transaction_types', where: 'code = ?', whereArgs: [code])).first;
    final typeId = type['id'] as String;

    final existing = await db.query(
      'operator_transaction_types',
      where: 'operator_id = ? AND transaction_type_id = ?',
      whereArgs: [operatorId, typeId],
    );
    if (existing.isNotEmpty) {
      final linkId = existing.first['id'] as String;
      await db.update(
        'operator_transaction_types',
        {'ussd_code': ussdCode, 'commission_taux': commissionTaux},
        where: 'id = ?',
        whereArgs: [linkId],
      );
      return linkId;
    }

    final linkId = _uuid.v4();
    await db.insert('operator_transaction_types', {
      'id': linkId,
      'operator_id': operatorId,
      'transaction_type_id': typeId,
      'ussd_code': ussdCode,
      'commission_taux': commissionTaux,
      'is_active': 1,
      'created_at': DateTime.now().toIso8601String(),
    });
    return linkId;
  }

  static Future<OperatorTransactionTypeOption> createCustomTypeForOperator({
    required String operatorId,
    required String label,
    required String defaultDirection,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final now = DateTime.now().toIso8601String();
    final code = _slugify(label);
    final typeId = _uuid.v4();
    final linkId = _uuid.v4();

    await db.insert('transaction_types', {
      'id': typeId,
      'code': code,
      'label': label,
      'default_direction': defaultDirection,
      'is_custom': 1,
      'created_at': now,
    });
    await db.insert('operator_transaction_types', {
      'id': linkId,
      'operator_id': operatorId,
      'transaction_type_id': typeId,
      'ussd_code': null,
      'commission_taux': 0,
      'is_active': 1,
      'created_at': now,
    });

    return OperatorTransactionTypeOption(
      linkId: linkId,
      transactionTypeId: typeId,
      code: code,
      label: label,
      defaultDirection: defaultDirection,
      isCustom: true,
    );
  }

  static String _slugify(String label) {
    final base = label
        .toLowerCase()
        .replaceAll(RegExp(r'[àâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[îï]'), 'i')
        .replaceAll(RegExp(r'[ôö]'), 'o')
        .replaceAll(RegExp(r'[ùûü]'), 'u')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    // Suffixe court pour éviter les collisions entre deux types custom au
    // libellé proche (le code n'a pas de contrainte unique côté local).
    return '${base}_${_uuid.v4().substring(0, 6)}';
  }
}
