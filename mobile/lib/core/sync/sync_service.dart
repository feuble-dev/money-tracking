import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../licence/licence_service.dart';
import '../onboarding/onboarding_state.dart';
import '../config/api_config.dart';
import '../network/api_client.dart';

const _syncBaseUrl = ApiConfig.sync;

/// Lot de lignes à pousser, avec les curseurs à enregistrer une fois le
/// push confirmé par le serveur.
class SyncBatch {
  final List<Map<String, Object?>> transactions;
  final List<Map<String, Object?>> clients;
  final List<Map<String, Object?>> caisseOps;
  final Map<String, int> cursors;

  const SyncBatch(this.transactions, this.clients, this.caisseOps, this.cursors);

  bool get isEmpty => transactions.isEmpty && clients.isEmpty && caisseOps.isEmpty;
}

/// Pousse en continu (D-sync, droits patron « lecture seule ») les
/// transactions/clients/opérations caisse de l'agence locale vers le
/// backend, pour que le patron d'un compte multi-agence voie le détail
/// complet de ses agences (sync.AgenceSyncDetailView côté backend). Comptes
/// Agence uniquement.
///
/// Deux curseurs par table :
/// - **insertion** (`rowid`) : les nouvelles lignes, y compris celles datées
///   dans le passé (rattrapage SMS D15, import d'historique) qu'un curseur
///   sur `created_at` ne voyait jamais ;
/// - **modification** (`sync_seq`, DB v17, posé par trigger) : une
///   transaction annulée, confirmée ou corrigée après son premier envoi est
///   renvoyée, et le patron voit son vrai statut.
/// L'upsert serveur par `local_id` est idempotent : un renvoi ne crée
/// jamais de doublon. Après une restauration de sauvegarde, [resetCursors]
/// repart de zéro.
class SyncService {
  static const _cursorTx = 'sync_cursor_transactions';
  static const _cursorTxSeq = 'sync_cursor_transactions_seq';
  static const _cursorClients = 'sync_cursor_clients';
  static const _cursorClientsSeq = 'sync_cursor_clients_seq';
  static const _cursorCaisseOps = 'sync_cursor_caisse_ops';
  static const _batch = 500;

  /// À appeler après une restauration de base : les rowid ne correspondent
  /// plus, on repousse tout (idempotent).
  static Future<void> resetCursors() async {
    final prefs = await SharedPreferences.getInstance();
    for (final k in [_cursorTx, _cursorTxSeq, _cursorClients, _cursorClientsSeq, _cursorCaisseOps]) {
      await prefs.remove(k);
    }
  }

  /// Ce qui reste à envoyer pour [agenceId] depuis les curseurs [cursors]
  /// (clé absente = 0). Séparé du réseau pour être testable.
  @visibleForTesting
  static Future<SyncBatch> pending(
      DatabaseExecutor db, String agenceId, Map<String, int> cursors) async {
    int c(String k) => cursors[k] ?? 0;

    const txSelect = '''
      SELECT t.rowid AS _rid, t.sync_seq AS _seq, t.id, o.name as operator_name,
             tt.label as type_label, t.transaction_type as type_code, t.direction,
             t.amount, t.commission, t.client_phone, t.client_name, t.status,
             t.source, t.created_at
      FROM transactions t
      LEFT JOIN operators o ON o.id = t.operator_id
      LEFT JOIN transaction_types tt ON tt.id = t.transaction_type_id
    ''';
    final txNew = await db.rawQuery(
        '$txSelect WHERE t.agence_id = ? AND t.rowid > ? ORDER BY t.rowid LIMIT $_batch',
        [agenceId, c(_cursorTx)]);
    final txChanged = await db.rawQuery(
        '$txSelect WHERE t.agence_id = ? AND t.sync_seq > ? ORDER BY t.sync_seq LIMIT $_batch',
        [agenceId, c(_cursorTxSeq)]);

    const clientSelect = '''
      SELECT rowid AS _rid, sync_seq AS _seq, id, first_name, last_name,
             phone_number, created_at
      FROM clients
    ''';
    final clientsNew = await db.rawQuery(
        '$clientSelect WHERE agence_id = ? AND rowid > ? ORDER BY rowid LIMIT $_batch',
        [agenceId, c(_cursorClients)]);
    final clientsChanged = await db.rawQuery(
        '$clientSelect WHERE agence_id = ? AND sync_seq > ? ORDER BY sync_seq LIMIT $_batch',
        [agenceId, c(_cursorClientsSeq)]);

    // Opérations de caisse : jamais modifiées, curseur d'insertion seul.
    final caisseOps = await db.rawQuery('''
      SELECT co.rowid AS _rid, co.id, o.name as operator_name, co.type, co.montant,
             co.note, co.created_at
      FROM caisse_operations co
      LEFT JOIN operators o ON o.id = co.operator_id
      WHERE co.agence_id = ? AND co.rowid > ?
      ORDER BY co.rowid LIMIT $_batch
    ''', [agenceId, c(_cursorCaisseOps)]);

    final next = Map<String, int>.from(cursors);
    void advance(String key, List<Map<String, Object?>> rows, String field) {
      if (rows.isNotEmpty) next[key] = rows.last[field] as int;
    }

    advance(_cursorTx, txNew, '_rid');
    advance(_cursorTxSeq, txChanged, '_seq');
    advance(_cursorClients, clientsNew, '_rid');
    advance(_cursorClientsSeq, clientsChanged, '_seq');
    advance(_cursorCaisseOps, caisseOps, '_rid');

    return SyncBatch(
      _merge(txNew, txChanged),
      _merge(clientsNew, clientsChanged),
      caisseOps,
      next,
    );
  }

  /// Nouvelles + modifiées, chaque ligne une seule fois.
  static List<Map<String, Object?>> _merge(
      List<Map<String, Object?>> a, List<Map<String, Object?>> b) {
    final seen = {for (final r in a) r['id']};
    return [...a, ...b.where((r) => !seen.contains(r['id']))];
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
      final cursors = {
        for (final k in [_cursorTx, _cursorTxSeq, _cursorClients, _cursorClientsSeq, _cursorCaisseOps])
          if (prefs.getInt(k) != null) k: prefs.getInt(k)!,
      };
      final batch = await pending(db, agenceId, cursors);
      if (batch.isEmpty) return;

      final response = await ApiClient.post('$_syncBaseUrl/push/', {
        'agence_id': backendAgenceId,
        'device_id': deviceId,
        'transactions': batch.transactions
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
        'clients': batch.clients
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
        'caisse_operations': batch.caisseOps
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

      // Les curseurs n'avancent qu'après confirmation du serveur ; un lot
      // plafonné reprendra au prochain push.
      if (response.ok) {
        for (final e in batch.cursors.entries) {
          await prefs.setInt(e.key, e.value);
        }
      }
    } catch (_) {
      // Silencieux et non bloquant : retentera au prochain déclenchement
      // (timer ou détection SMS), rien n'est perdu.
    }
  }
}
