import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../licence/licence_service.dart';
import '../onboarding/onboarding_state.dart';
import '../config/api_config.dart';
import '../network/api_client.dart';

const _syncBaseUrl = ApiConfig.sync;

/// Pousse en continu (D-sync, droits patron confirmés "lecture seule") les
/// transactions/clients/opérations caisse de l'agence locale vers le
/// backend, pour que le "patron" d'un compte multi-agence voie le détail
/// complet de ses agences (voir sync.AgenceSyncDetailView côté backend).
/// Ne concerne que les comptes Agence — jamais les comptes Particulier
/// (pas de notion d'agence à faire remonter).
///
/// Curseur par table sur l'ORDRE D'INSERTION (`rowid` SQLite), pas sur
/// `created_at` : le rattrapage SMS au démarrage (D15) et l'import
/// d'historique insèrent des transactions DATÉES DANS LE PASSÉ, qu'un
/// curseur `created_at > dernier push` ne voyait jamais — le patron ne les
/// recevait pas. Les tables n'ont pas d'INTEGER PRIMARY KEY et l'app ne fait
/// jamais de VACUUM, donc le rowid croît avec chaque insertion ; après une
/// restauration de sauvegarde, [resetCursors] repart de zéro (upsert
/// idempotent côté serveur, aucun doublon).
///
/// Limite connue : une modification après coup (ex. transaction annulée)
/// n'est pas re-poussée — il faudrait une colonne `updated_at` suivie.
class SyncService {
  static const _cursorTx = 'sync_cursor_transactions';
  static const _cursorClients = 'sync_cursor_clients';
  static const _cursorCaisseOps = 'sync_cursor_caisse_ops';

  /// À appeler après une restauration de base : les rowid ne correspondent
  /// plus, on repousse tout (idempotent).
  static Future<void> resetCursors() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cursorTx);
    await prefs.remove(_cursorClients);
    await prefs.remove(_cursorCaisseOps);
  }

  static Future<void> pushIfNeeded() async {
    try {
      final accountType = await OnboardingStatusService().getAccountType();
      if (accountType != 'agence') return;

      final db = await DatabaseHelper.instance.database;
      final agences = await db.query(
        'agences',
        where: 'backend_agence_id IS NOT NULL',
        limit: 1,
      );
      if (agences.isEmpty) return;
      final agenceId = agences.first['id'] as String;
      final backendAgenceId = agences.first['backend_agence_id'] as int;

      final deviceId = await LicenceService.getDeviceId();
      final prefs = await SharedPreferences.getInstance();
      final txCursor = prefs.getInt(_cursorTx) ?? 0;
      final clientsCursor = prefs.getInt(_cursorClients) ?? 0;
      final caisseCursor = prefs.getInt(_cursorCaisseOps) ?? 0;

      final transactions = await db.rawQuery(
        '''
        SELECT t.rowid AS _rid, t.id, o.name as operator_name, tt.label as type_label,
               t.transaction_type as type_code, t.direction, t.amount, t.commission,
               t.client_phone, t.client_name, t.status, t.source, t.created_at
        FROM transactions t
        LEFT JOIN operators o ON o.id = t.operator_id
        LEFT JOIN transaction_types tt ON tt.id = t.transaction_type_id
        WHERE t.agence_id = ? AND t.rowid > ?
        ORDER BY t.rowid ASC
        LIMIT 500
      ''',
        [agenceId, txCursor],
      );

      final clients = await db.rawQuery(
        '''
        SELECT rowid AS _rid, id, first_name, last_name, phone_number, created_at
        FROM clients
        WHERE agence_id = ? AND rowid > ?
        ORDER BY rowid ASC
        LIMIT 500
      ''',
        [agenceId, clientsCursor],
      );

      final caisseOps = await db.rawQuery(
        '''
        SELECT co.rowid AS _rid, co.id, o.name as operator_name, co.type, co.montant, co.note, co.created_at
        FROM caisse_operations co
        LEFT JOIN operators o ON o.id = co.operator_id
        WHERE co.agence_id = ? AND co.rowid > ?
        ORDER BY co.rowid ASC
        LIMIT 500
      ''',
        [agenceId, caisseCursor],
      );

      if (transactions.isEmpty && clients.isEmpty && caisseOps.isEmpty) return;

      final response = await ApiClient.post('$_syncBaseUrl/push/', {
        'agence_id': backendAgenceId,
        'device_id': deviceId,
        'transactions': transactions
            .map(
              (t) => {
                'local_id': t['id'],
                'operator_name': t['operator_name'] ?? '',
                'transaction_type_code': t['type_code'] ?? '',
                'transaction_type_label':
                    t['type_label'] ?? t['type_code'] ?? '',
                'direction': t['direction'] ?? '',
                'amount': t['amount'],
                'commission': t['commission'],
                'client_phone': t['client_phone'] ?? '',
                'client_name': t['client_name'] ?? '',
                'status': t['status'] ?? '',
                'source': t['source'] ?? '',
                'created_at': t['created_at'],
              },
            )
            .toList(),
        'clients': clients
            .map(
              (c) => {
                'local_id': c['id'],
                'first_name': c['first_name'] ?? '',
                'last_name': c['last_name'] ?? '',
                'phone_number': c['phone_number'] ?? '',
                'created_at': c['created_at'],
              },
            )
            .toList(),
        'caisse_operations': caisseOps
            .map(
              (o) => {
                'local_id': o['id'],
                'operator_name': o['operator_name'] ?? '',
                'type': o['type'] ?? '',
                'montant': o['montant'],
                'note': o['note'] ?? '',
                'created_at': o['created_at'],
              },
            )
            .toList(),
      }, timeout: const Duration(seconds: 20));

      if (response.ok) {
        // Chaque table avance indépendamment jusqu'à sa dernière ligne
        // envoyée ; une table plafonnée à 500 reprendra au prochain push.
        if (transactions.isNotEmpty) {
          await prefs.setInt(_cursorTx, transactions.last['_rid'] as int);
        }
        if (clients.isNotEmpty) {
          await prefs.setInt(_cursorClients, clients.last['_rid'] as int);
        }
        if (caisseOps.isNotEmpty) {
          await prefs.setInt(_cursorCaisseOps, caisseOps.last['_rid'] as int);
        }
      }
    } catch (_) {
      // Silencieux et non-bloquant — retentera au prochain déclenchement
      // (timer périodique ou détection SMS), aucune donnée n'est perdue
      // puisque le watermark n'avance qu'en cas de succès confirmé.
    }
  }
}
