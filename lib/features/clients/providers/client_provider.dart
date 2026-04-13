import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/database_helper.dart';
import '../models/client_model.dart';

const _uuid = Uuid();

/// Filtre opérateur pour les clients
final clientOperatorFilterProvider = StateProvider<String?>((ref) => null);

/// Provider pour la liste des clients
final clientsProvider =
    StateNotifierProvider<ClientsNotifier, AsyncValue<List<ClientModel>>>(
        (ref) {
  return ClientsNotifier();
});

/// Provider pour les suggestions d'auto-complétion par numéro
final clientSuggestionsProvider =
    FutureProvider.family<List<ClientModel>, String>((ref, query) async {
  if (query.length < 2) return [];
  final db = await DatabaseHelper.instance.database;
  try {
    final results = await db.rawQuery('''
      SELECT c.*, o.name as operator_name
      FROM clients c
      LEFT JOIN operators o ON c.operator_id = o.id
      WHERE c.phone_number LIKE ? OR c.first_name LIKE ? OR c.last_name LIKE ?
      LIMIT 10
    ''', ['%$query%', '%$query%', '%$query%']);
    return results.map((e) => ClientModel.fromMap(e)).toList();
  } catch (_) {
    // Fallback si la colonne operator_id n'existe pas encore
    final results = await db.query('clients',
      where: 'phone_number LIKE ? OR first_name LIKE ? OR last_name LIKE ?',
      whereArgs: ['%$query%', '%$query%', '%$query%'],
      limit: 10,
    );
    return results.map((e) => ClientModel.fromMap(e)).toList();
  }
});

/// Notifier pour les opérations CRUD sur les clients
class ClientsNotifier extends StateNotifier<AsyncValue<List<ClientModel>>> {
  ClientsNotifier() : super(const AsyncValue.loading()) {
    loadClients();
  }

  Future<void> loadClients({String? search, String? operatorId}) async {
    try {
      final db = await DatabaseHelper.instance.database;

      try {
        // Requête avec JOIN opérateur
        final where = StringBuffer();
        final whereArgs = <dynamic>[];

        if (search != null && search.isNotEmpty) {
          where.write('(c.first_name LIKE ? OR c.last_name LIKE ? OR c.phone_number LIKE ?)');
          whereArgs.addAll(['%$search%', '%$search%', '%$search%']);
        }
        if (operatorId != null) {
          if (where.isNotEmpty) where.write(' AND ');
          where.write('c.operator_id = ?');
          whereArgs.add(operatorId);
        }

        final whereClause = where.isEmpty ? '' : 'WHERE $where';

        final results = await db.rawQuery('''
          SELECT c.*, o.name as operator_name
          FROM clients c
          LEFT JOIN operators o ON c.operator_id = o.id
          $whereClause
          ORDER BY c.first_name ASC
          LIMIT 200
        ''', whereArgs);

        state = AsyncValue.data(
            results.map((e) => ClientModel.fromMap(e)).toList());
      } catch (_) {
        // Fallback sans operator_id (migration pas encore faite)
        final where = <String>[];
        final whereArgs = <dynamic>[];
        if (search != null && search.isNotEmpty) {
          where.add('(first_name LIKE ? OR last_name LIKE ? OR phone_number LIKE ?)');
          whereArgs.addAll(['%$search%', '%$search%', '%$search%']);
        }
        final whereClause = where.isEmpty ? null : where.join(' AND ');
        final results = await db.query('clients',
            where: whereClause, whereArgs: whereArgs.isEmpty ? null : whereArgs,
            orderBy: 'first_name ASC', limit: 200);
        state = AsyncValue.data(
            results.map((e) => ClientModel.fromMap(e)).toList());
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<ClientModel> addClient(ClientModel client) async {
    final db = await DatabaseHelper.instance.database;
    // Vérifier si un client existe déjà avec ce numéro
    final existing = await db.query('clients',
        where: 'phone_number = ?',
        whereArgs: [client.phoneNumber],
        limit: 1);
    if (existing.isNotEmpty) {
      // Mettre à jour le client existant avec les nouvelles infos
      final existingClient = ClientModel.fromMap(existing.first);
      final updated = existingClient.copyWith(
        firstName: client.firstName.isNotEmpty ? client.firstName : null,
        lastName: client.lastName.isNotEmpty ? client.lastName : null,
        cnibNumber: client.cnibNumber,
        birthDate: client.birthDate,
        operatorId: client.operatorId ?? existingClient.operatorId,
      );
      await db.update('clients', updated.toMap(),
          where: 'id = ?', whereArgs: [existingClient.id]);
      await loadClients();
      return updated;
    }
    await db.insert('clients', client.toMap());
    await loadClients();
    return client;
  }

  Future<void> updateClient(ClientModel client) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('clients', client.toMap(),
        where: 'id = ?', whereArgs: [client.id]);
    await loadClients();
  }

  Future<void> deleteClient(String id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
    await loadClients();
  }

  Future<ClientModel?> findByPhone(String phone) async {
    final db = await DatabaseHelper.instance.database;
    final results = await db.query('clients',
        where: 'phone_number = ?', whereArgs: [phone]);
    if (results.isEmpty) return null;
    return ClientModel.fromMap(results.first);
  }

  static String generateId() => _uuid.v4();
}
