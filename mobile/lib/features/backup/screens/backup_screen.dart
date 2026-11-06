import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/format/formats.dart';
import '../data/backup_crypto.dart';
import '../data/backup_service.dart';
import '../widgets/backup_password_dialog.dart';

/// Sauvegarde chiffrée de la base (voir BackupService / BackupCrypto).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;
  List<BackupFile> _backups = const [];
  final Map<String, BackupKind> _kinds = {};

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final list = await BackupService.list();
    for (final b in list) {
      _kinds[b.file.path] ??= await BackupService.kindOf(b.file);
    }
    if (mounted) setState(() => _backups = list);
  }

  Future<void> _create() async {
    final password = await showBackupPasswordDialog(context, confirm: true);
    if (password == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await BackupService.create(password);
      await _reload();
      _snack('Sauvegarde chiffrée créée');
    } catch (e) {
      _snack('Échec de la sauvegarde : $e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde')),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withAlpha(110),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, color: scheme.primary, size: 32),
                  const SizedBox(height: 12),
                  Text('Sauvegarde chiffrée',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(
                    'Une copie complète de vos données, protégée par un mot de '
                    'passe. Vous pouvez la partager (WhatsApp, Drive…) sans '
                    'risque : sans le mot de passe, elle est illisible. '
                    'Les ${BackupService.keepLast} dernières sont conservées.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy ? null : _create,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save_outlined),
                      label: Text(_busy ? 'Chiffrement…' : 'Créer une sauvegarde'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_backups.isNotEmpty)
              Text('Sauvegardes sur ce téléphone',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final b in _backups)
              Card(
                child: ListTile(
                  leading: Icon(
                    _kinds[b.file.path] == BackupKind.encrypted
                        ? Icons.lock
                        : Icons.lock_open,
                    color: _kinds[b.file.path] == BackupKind.encrypted
                        ? scheme.primary
                        : Colors.orange,
                  ),
                  title: Text(AppFormats.dateTime.format(b.modified)),
                  subtitle: Text(
                    '${(b.sizeBytes / 1024).toStringAsFixed(0)} Ko · '
                    '${_kinds[b.file.path] == BackupKind.encrypted ? 'chiffrée' : 'ancienne, non chiffrée'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Partager',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () => Share.shareXFiles([XFile(b.file.path)],
                        subject: 'Sauvegarde MoneyTracking'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
