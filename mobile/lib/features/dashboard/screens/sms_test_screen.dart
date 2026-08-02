import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/sms/sms_listener.dart';
import '../../../core/theme/app_colors.dart';

/// Écran de test — affiche les SMS captés par le service principal
/// N'écoute PAS lui-même — utilise le provider partagé
class SmsTestScreen extends ConsumerStatefulWidget {
  const SmsTestScreen({super.key});

  @override
  ConsumerState<SmsTestScreen> createState() => _SmsTestScreenState();
}

class _SmsTestScreenState extends ConsumerState<SmsTestScreen> {
  final List<Map<String, String>> _smsRecus = [];

  @override
  void initState() {
    super.initState();
    // Brancher un callback temporaire sur le service existant
    SmsListenerService().onSmsRawReceived = (sender, body) {
      if (mounted) {
        setState(() {
          _smsRecus.insert(0, {
            'sender': sender,
            'body': body,
            'time': DateTime.now().toString(),
          });
        });
      }
    };
  }

  @override
  void dispose() {
    SmsListenerService().onSmsRawReceived = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isActive = ref.watch(smsServiceActiveProvider);
    final lastSms = ref.watch(lastSmsReceivedProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Test SMS natif'),
        actions: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.circle, size: 12,
                    color: isActive ? Colors.greenAccent : Colors.red),
                const SizedBox(width: 6),
                Text(isActive ? 'Actif' : 'Inactif',
                    style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primaryColor.withAlpha(15),
            padding: const EdgeInsets.all(12),
            child: Text(
              'Service SMS: ${isActive ? "actif" : "inactif"}\n'
              'Dernier SMS: ${lastSms ?? "aucun"}',
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            ),
          ),
          Container(
            width: double.infinity,
            color: Colors.amber.shade100,
            padding: const EdgeInsets.all(16),
            child: const Text(
              'Envoyez un SMS depuis un autre téléphone. '
              'Il doit apparaître ici immédiatement.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('${_smsRecus.length} SMS reçu(s)',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: _smsRecus.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.sms_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        const Text('En attente de SMS...',
                            style: TextStyle(color: Colors.grey, fontSize: 15)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _smsRecus.length,
                    itemBuilder: (context, index) {
                      final sms = _smsRecus[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: ListTile(
                          leading: const Icon(Icons.sms, color: AppColors.withdrawColor),
                          title: Text(sms['sender'] ?? '',
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(sms['body'] ?? ''),
                              const SizedBox(height: 4),
                              Text(sms['time'] ?? '',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
