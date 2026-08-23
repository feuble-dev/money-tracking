import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../licence/licence_service.dart';
import '../onboarding/onboarding_state.dart';

const _syncBaseUrl = 'https://api-money-tracking.rf-appdev.online/api/sync';
// const _syncBaseUrl = 'http://localhost:8000/api/sync';

/// Pousse en continu (D-sync, droits patron confirmés "lecture seule") les
/// transactions/clients/opérations caisse de l'agence locale vers le
/// backend, pour que le "patron" d'un compte multi-agence voie le détail
/// complet de ses agences (voir sync.AgenceSyncDetailView côté backend).
/// Ne concerne que les comptes Agence — jamais les comptes Particulier
/// (pas de notion d'agence à faire remonter).
///
/// Watermark simple (created_at > dernier push réussi) : les données de ce
/// domaine sont quasi append-only (une transaction confirmée n'est plus
/// modifiée), donc pas besoin d'un vrai suivi de delta par ligne.
class SyncService {
  static const _prefsKeyLastPush = 'sync_last_push_at';

  static Future<void> pushIfNeeded() async {
    try {
      final accountType = await OnboardingStatusService().getAccountType();
      if (accountType != 'agence') return;

      final db = await DatabaseHelper.instance.database;
      final agences = await db.query('agences', where: 'backend_agence_id IS NOT NULL', limit: 1);
      if (agences.isEmpty) return;
      final agenceId = agences.first['id'] as String;
      final backendAgenceId = agences.first['backend_agence_id'] as int;

      final deviceId = await LicenceService.getDeviceId();
      final prefs = await SharedPreferences.getInstance();
      final since = prefs.getString(_prefsKeyLastPush) ?? '2000-01-01T00:00:00.000';

      final transactions = await db.rawQuery('''
        SELECT t.id, o.name as operator_name, tt.label as type_label,
               t.transaction_type as type_code, t.direction, t.amount, t.commission,
               t.client_phone, t.client_name, t.status, t.source, t.created_at
        FROM transactions t
        LEFT JOIN operators o ON o.id = t.operator_id
        LEFT JOIN transaction_types tt ON tt.id = t.transaction_type_id
        WHERE t.agence_id = ? AND t.created_at > ?
        ORDER BY t.created_at ASC
        LIMIT 500
      ''', [agenceId, since]);

      final clients = await db.rawQuery('''
        SELECT id, first_name, last_name, phone_number, created_at
        FROM clients
        WHERE agence_id = ? AND created_at > ?
        ORDER BY created_at ASC
        LIMIT 500
      ''', [agenceId, since]);

      final caisseOps = await db.rawQuery('''
        SELECT co.id, o.name as operator_name, co.type, co.montant, co.note, co.created_at
        FROM caisse_operations co
        LEFT JOIN operators o ON o.id = co.operator_id
        WHERE co.agence_id = ? AND co.created_at > ?
        ORDER BY co.created_at ASC
        LIMIT 500
      ''', [agenceId, since]);

      if (transactions.isEmpty && clients.isEmpty && caisseOps.isEmpty) return;

      final response = await http
          .post(
            Uri.parse('$_syncBaseUrl/push/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'agence_id': backendAgenceId,
              'device_id': deviceId,
              'transactions': transactions
                  .map((t) => {
                        'local_id': t['id'],
                        'operator_name': t['operator_name'] ?? '',
                        'transaction_type_code': t['type_code'] ?? '',
                        'transaction_type_label': t['type_label'] ?? t['type_code'] ?? '',
                        'direction': t['direction'] ?? '',
                        'amount': t['amount'],
                        'commission': t['commission'],
                        'client_phone': t['client_phone'] ?? '',
                        'client_name': t['client_name'] ?? '',
                        'status': t['status'] ?? '',
                        'source': t['source'] ?? '',
                        'created_at': t['created_at'],
                      })
                  .toList(),
              'clients': clients
                  .map((c) => {
                        'local_id': c['id'],
                        'first_name': c['first_name'] ?? '',
                        'last_name': c['last_name'] ?? '',
                        'phone_number': c['phone_number'] ?? '',
                        'created_at': c['created_at'],
                      })
                  .toList(),
              'caisse_operations': caisseOps
                  .map((o) => {
                        'local_id': o['id'],
                        'operator_name': o['operator_name'] ?? '',
                        'type': o['type'] ?? '',
                        'montant': o['montant'],
                        'note': o['note'] ?? '',
                        'created_at': o['created_at'],
                      })
                  .toList(),
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        // Nouveau curseur = le plus ancien "dernier élément envoyé" parmi
        // les 3 tables (pas "maintenant") — une table plafonnée à 500
        // lignes peut avoir un reliquat plus ancien que "maintenant" que ce
        // push n'a pas envoyé ; le prochain push doit encore le voir.
        final candidates = <String>[
          if (transactions.isNotEmpty) transactions.last['created_at'] as String,
          if (clients.isNotEmpty) clients.last['created_at'] as String,
          if (caisseOps.isNotEmpty) caisseOps.last['created_at'] as String,
        ];
        if (candidates.isNotEmpty) {
          candidates.sort();
          await prefs.setString(_prefsKeyLastPush, candidates.first);
        }
      }
    } catch (_) {
      // Silencieux et non-bloquant — retentera au prochain déclenchement
      // (timer périodique ou détection SMS), aucune donnée n'est perdue
      // puisque le watermark n'avance qu'en cas de succès confirmé.
    }
  }
}
