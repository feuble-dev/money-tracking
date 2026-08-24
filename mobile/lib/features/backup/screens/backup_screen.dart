import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../../core/theme/app_colors.dart';

/// Écran de sauvegarde de la base de données
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isLoading = false;
  List<FileSystemEntity> _backups = [];

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<String> get _backupDir async {
    final dir = await getApplicationDocumentsDirectory();
    final backupPath = '${dir.path}/backups';
    await Directory(backupPath).create(recursive: true);
    return backupPath;
  }

  Future<void> _loadBackups() async {
    try {
      final dir = Directory(await _backupDir);
      final files = dir
          .listSync()
          .where((f) => f.path.endsWith('.mmtbak'))
          .toList()
        ..sort((a, b) => b.path.compareTo(a.path));
      setState(() => _backups = files);
    } catch (_) {
      setState(() => _backups = []);
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isLoading = true);

    try {
      final dbPath = await getDatabasesPath();
      final sourcePath = p.join(dbPath, 'moneytracking.db');
      final source = File(sourcePath);

      if (!await source.exists()) {
        throw Exception('Base de données introuvable');
      }

      final backupPath = await _backupDir;
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final destPath = '$backupPath/moneytracking_backup_$timestamp.mmtbak';

      await source.copy(destPath);

      // Nettoyer les anciennes sauvegardes (garder les 7 dernières)
      await _cleanOldBackups();
      await _loadBackups();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sauvegarde créée avec succès'),
            backgroundColor: AppColors.withdrawColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareBackup(String path) async {
    await Share.shareXFiles(
      [XFile(path)],
      subject: 'Sauvegarde MoneyTracking',
    );
  }

  Future<void> _cleanOldBackups() async {
    final dir = Directory(await _backupDir);
    final files = dir
        .listSync()
        .where((f) => f.path.endsWith('.mmtbak'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path));

    if (files.length > 7) {
      for (int i = 7; i < files.length; i++) {
        await files[i].delete();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sauvegarde')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(Icons.backup,
                      size: 48, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 12),
                  const Text(
                    'Sauvegarder votre base de données',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crée une copie de toutes vos données. Les 7 dernières sauvegardes sont conservées.',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _createBackup,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(_isLoading
                          ? 'Sauvegarde...'
                          : 'Créer une sauvegarde'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (_backups.isNotEmpty) ...[
            Text('Sauvegardes existantes',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            ..._backups.map((file) {
              final name = p.basename(file.path);
              final stat = file.statSync();
              final sizeKb = (stat.size / 1024).toStringAsFixed(0);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.description),
                  title: Text(name, style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yyyy HH:mm').format(stat.modified)} - $sizeKb Ko',
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.share, size: 20),
                    onPressed: () => _shareBackup(file.path),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
