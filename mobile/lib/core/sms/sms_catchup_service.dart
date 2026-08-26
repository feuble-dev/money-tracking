import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../database/database_helper.dart';
import 'sms_processing_pipeline.dart';

/// Rattrapage silencieux des SMS manqués pendant que l'app était fermée
/// (D15) — appelé une fois au démarrage, dès que la permission SMS est
/// accordée (main.dart). Pour chaque opérateur déjà configuré, compare le
/// dernier SMS connu en base (sms_messages) à la boîte de réception réelle
/// du téléphone : tout message plus récent est repassé dans le pipeline
/// partagé processIncomingSms(), exactement comme s'il venait d'arriver.
///
/// Volontairement distinct de HistoriqueImportService (l'import payant D5,
/// qui backfill une plage choisie par l'utilisateur) : ce rattrapage est
/// gratuit, automatique, et ne couvre que "depuis le dernier message connu"
/// — un opérateur pour lequel aucun SMS n'a jamais été enregistré n'est pas
/// concerné (ce serait un backfill complet, hors sujet ici).
class SmsCatchupService {
  static const _smsChannel =
      MethodChannel('com.rftech.moneytracking/sms_inbox');

  Future<void> run() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final operators = await db.query(
        'operators',
        where: "is_active = 1 AND sms_sender IS NOT NULL AND sms_sender != ''",
      );
      if (operators.isEmpty) return;

      final now = DateTime.now();

      for (final op in operators) {
        final sender = (op['sms_sender'] as String?)?.trim() ?? '';
        if (sender.isEmpty) continue;

        final lastRows = await db.rawQuery('''
          SELECT MAX(received_at) as last_date FROM sms_messages
          WHERE LOWER(sender) LIKE '%' || LOWER(?) || '%'
             OR LOWER(?) LIKE '%' || LOWER(sender) || '%'
        ''', [sender, sender]);
        final lastDateStr = lastRows.first['last_date'] as String?;
        if (lastDateStr == null) {
          // Aucun message connu pour cet opérateur — pas de rattrapage
          // gratuit ici, seulement pour les opérateurs déjà "vivants".
          continue;
        }

        final lastDate = DateTime.parse(lastDateStr);
        if (!lastDate.isBefore(now)) continue;

        List<Map<String, dynamic>> messages;
        try {
          final result = await _smsChannel.invokeMethod('getInboxSms', {
            'dateFrom':
                lastDate.add(const Duration(milliseconds: 1)).millisecondsSinceEpoch,
            'dateTo': now.millisecondsSinceEpoch,
          });
          final rawList = result as List? ?? [];
          messages =
              rawList.map((item) => Map<String, dynamic>.from(item as Map)).toList();
        } catch (e) {
          debugPrint('[SmsCatchup] Lecture inbox impossible pour $sender: $e');
          continue;
        }

        final opMessages = messages.where((sms) {
          final address = ((sms['address'] ?? '') as String).toLowerCase();
          final s = sender.toLowerCase();
          return address.contains(s) || s.contains(address);
        }).toList();

        if (opMessages.isEmpty) continue;
        debugPrint(
            '[SmsCatchup] ${opMessages.length} SMS manqué(s) pour $sender depuis $lastDate');

        for (final sms in opMessages) {
          final body = (sms['body'] ?? '') as String;
          final address = (sms['address'] ?? '') as String;
          final dateMs = sms['date'] as int? ?? 0;
          if (body.isEmpty || dateMs == 0) continue;
          await processIncomingSms(
            address,
            body,
            receivedAt: DateTime.fromMillisecondsSinceEpoch(dateMs),
          );
        }
      }
    } catch (e) {
      debugPrint('[SmsCatchup] Erreur: $e');
    }
  }
}
