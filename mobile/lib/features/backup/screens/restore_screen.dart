import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../data/backup_crypto.dart';
import '../data/backup_service.dart';
import '../widgets/backup_password_dialog.dart';

/// Restauration d'une sauvegarde (chiffrée, ou ancienne en clair).
class RestoreScreen extends StatefulWidget {
  const RestoreScreen({super.key});

  @override
  State<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends State<RestoreScreen> {
  bool _busy = false;

  Future<void> _pickAndRestore() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.any);
    final path = picked?.files.single.path;
    if (path == null || !mounted) return;
    final file = File(path);

    final kind = await BackupService.kindOf(file);
    if (kind == BackupKind.unknown) {
      return _snack("Ce fichier n'est pas une sauvegarde MoneyTracking",
          error: true);
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remplacer les données actuelles ?'),
        content: const Text(
          'Toutes les données de ce téléphone seront remplacées par celles '
          'de la sauvegarde. Une copie de sécurité de la base actuelle est '
          'conservée.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Continuer')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    String? error;
    while (mounted) {
      String? password;
      if (kind == BackupKind.encrypted) {
        if (!mounted) return;
        password = await showBackupPasswordDialog(context,
            confirm: false, error: error);
        if (password == null) return;
      }
      setState(() => _busy = true);
      try {
        await BackupService.restore(file, password: password);
        _snack('Restauration réussie. Redémarrez l\'application.');
        return;
      } on BackupWrongPassword {
        error = 'Mot de passe incorrect';
      } catch (e) {
        _snack('Échec de la restauration : $e', error: true);
        return;
      } finally {
        if (mounted) setState(() => _busy = false);
      }
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 5),
      backgroundColor: error ? Theme.of(context).colorScheme.error : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Restauration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withAlpha(110),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.settings_backup_restore,
                    color: scheme.tertiary, size: 32),
                const SizedBox(height: 12),
                Text('Restaurer une sauvegarde',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'Choisissez un fichier .mmtbak. Une sauvegarde chiffrée '
                  'demande le mot de passe choisi lors de sa création.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    onPressed: _busy ? null : _pickAndRestore,
                    icon: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.folder_open),
                    label: Text(_busy ? 'Restauration…' : 'Choisir un fichier'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
