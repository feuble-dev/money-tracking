import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_colors.dart';

/// Provider pour la liste des SMS enregistrés
final smsJournalProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final db = await DatabaseHelper.instance.database;
  return db.rawQuery('''
    SELECT sm.*, o.name as operator_name
    FROM sms_messages sm
    LEFT JOIN operators o ON EXISTS (
      SELECT 1 FROM operators o2
      WHERE o2.is_active = 1
        AND LOWER(o2.sms_sender) = LOWER(sm.sender)
      LIMIT 1
    ) AND o.id = (
      SELECT o3.id FROM operators o3
      WHERE o3.is_active = 1
        AND LOWER(o3.sms_sender) = LOWER(sm.sender)
      LIMIT 1
    )
    ORDER BY sm.received_at DESC
    LIMIT 100
  ''');
});

/// Écran journal des SMS pour diagnostic
class SmsJournalScreen extends ConsumerWidget {
  const SmsJournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journalAsync = ref.watch(smsJournalProvider);
    final dateFormat = DateFormat('dd/MM HH:mm', 'fr_FR');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal SMS'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(smsJournalProvider),
          ),
        ],
      ),
      body: journalAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (messages) {
          if (messages.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sms_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text('Aucun SMS enregistré',
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Text(
                    'Les SMS des opérateurs apparaîtront ici\nlorsqu\'ils seront détectés.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: messages.length,
            itemBuilder: (context, index) {
              final sms = messages[index];
              final processed = (sms['processed'] as int?) == 1;
              final sender = sms['sender'] as String? ?? 'Inconnu';
              final body = sms['body'] as String? ?? '';
              final receivedAt = sms['received_at'] as String?;
              final txId = sms['transaction_id'] as String?;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  leading: Icon(
                    processed ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: processed ? AppColors.withdrawColor : Colors.grey,
                    size: 20,
                  ),
                  title: Text(sender,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  subtitle: Text(
                    receivedAt != null
                        ? dateFormat.format(DateTime.parse(receivedAt))
                        : '',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: processed
                              ? AppColors.withdrawColor.withAlpha(20)
                              : Colors.orange.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          processed ? 'Traité' : 'Ignoré',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: processed
                                ? AppColors.withdrawColor
                                : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(body,
                                style: const TextStyle(
                                    fontFamily: 'monospace', fontSize: 12)),
                          ),
                          if (txId != null) ...[
                            const SizedBox(height: 8),
                            Text('Transaction: $txId',
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
