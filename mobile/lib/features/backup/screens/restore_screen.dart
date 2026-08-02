import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/theme/app_colors.dart';

/// Écran de restauration de la base de données
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key});

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  bool _isLoading = false;

  Future<void> _pickAndRestore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
    );

    if (result == null || result.files.single.path == null) return;

    final filePath = result.files.single.path!;
    if (!filePath.endsWith('.mmtbak') && !filePath.endsWith('.db')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fichier invalide. Sélectionnez un fichier .mmtbak'),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    // Confirmation
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurer la base de données ?'),
        content: const Text(
          'Toutes les données actuelles seront remplacées par celles de la sauvegarde. '
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentColor),
            child: const Text('Restaurer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);

    try {
      // Fermer la DB actuelle
      await DatabaseHelper.instance.close();

      // Copier le fichier de sauvegarde
      final dbPath = await getDatabasesPath();
      final destPath = p.join(dbPath, 'moneytracking.db');
      final source = File(filePath);
      await source.copy(destPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Restauration réussie. Redémarrez l\'application.'),
            backgroundColor: AppColors.withdrawColor,
            duration: Duration(seconds: 5),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Restauration')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Icon(Icons.restore, size: 48, color: AppColors.accentColor),
                    const SizedBox(height: 12),
                    const Text(
                      'Restaurer depuis une sauvegarde',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sélectionnez un fichier .mmtbak pour restaurer vos données. '
                      'Les données actuelles seront écrasées.',
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _pickAndRestore,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2))
                            : const Icon(Icons.folder_open),
                        label: Text(_isLoading
                            ? 'Restauration...'
                            : 'Sélectionner un fichier'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
