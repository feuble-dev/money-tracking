import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_colors.dart';

/// Provider pour le délai de verrouillage (en minutes)
final lockTimeoutProvider = StateProvider<int>((ref) => 5);

/// Écran de configuration du délai de verrouillage
class LockTimeoutScreen extends ConsumerStatefulWidget {
  const LockTimeoutScreen({super.key});

  @override
  ConsumerState<LockTimeoutScreen> createState() => _LockTimeoutScreenState();
}

class _LockTimeoutScreenState extends ConsumerState<LockTimeoutScreen> {
  int _selectedTimeout = 5;

  static const _timeoutOptions = [
    (0, 'Immédiat'),
    (1, '1 minute'),
    (2, '2 minutes'),
    (5, '5 minutes'),
    (10, '10 minutes'),
    (15, '15 minutes'),
    (30, '30 minutes'),
  ];

  @override
  void initState() {
    super.initState();
    _loadTimeout();
  }

  Future<void> _loadTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedTimeout = prefs.getInt('lock_timeout_minutes') ?? 5;
    });
  }

  Future<void> _saveTimeout(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lock_timeout_minutes', minutes);
    setState(() => _selectedTimeout = minutes);
    ref.read(lockTimeoutProvider.notifier).state = minutes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Délai de verrouillage')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined,
                      color: AppColors.primaryColor, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'L\'application se verrouille après une période d\'inactivité.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ..._timeoutOptions.map((option) {
            final (minutes, label) = option;
            final isSelected = minutes == _selectedTimeout;
            return ListTile(
              title: Text(label),
              leading: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primaryColor : null,
              ),
              onTap: () => _saveTimeout(minutes),
            );
          }),
        ],
      ),
    );
  }
}
