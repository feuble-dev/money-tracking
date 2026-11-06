import 'package:flutter/material.dart';

import '../data/backup_service.dart';

/// Demande le mot de passe d'une sauvegarde. [confirm] = création (saisie
/// deux fois + avertissement) ; sinon restauration (une saisie).
Future<String?> showBackupPasswordDialog(BuildContext context,
    {required bool confirm, String? error}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _BackupPasswordDialog(confirm: confirm, error: error),
  );
}

class _BackupPasswordDialog extends StatefulWidget {
  final bool confirm;
  final String? error;
  const _BackupPasswordDialog({required this.confirm, this.error});

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final _pwd = TextEditingController();
  final _pwd2 = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.error;
  }

  @override
  void dispose() {
    _pwd.dispose();
    _pwd2.dispose();
    super.dispose();
  }

  void _submit() {
    final pwd = _pwd.text;
    if (widget.confirm) {
      if (pwd.length < BackupService.minPasswordLength) {
        setState(() => _error =
            'Au moins ${BackupService.minPasswordLength} caractères');
        return;
      }
      if (pwd != _pwd2.text) {
        setState(() => _error = 'Les deux mots de passe sont différents');
        return;
      }
    } else if (pwd.isEmpty) {
      return;
    }
    Navigator.pop(context, pwd);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _obscure = !_obscure),
          ),
        );

    return AlertDialog(
      title: Text(widget.confirm
          ? 'Protéger la sauvegarde'
          : 'Mot de passe de la sauvegarde'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.confirm) ...[
              Text(
                'Vos données seront chiffrées. Sans ce mot de passe, '
                'personne — pas même nous — ne pourra restaurer la sauvegarde.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _pwd,
              obscureText: _obscure,
              autofocus: true,
              decoration: deco('Mot de passe'),
              onSubmitted: (_) => widget.confirm ? null : _submit(),
            ),
            if (widget.confirm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _pwd2,
                obscureText: _obscure,
                decoration: deco('Confirmer'),
                onSubmitted: (_) => _submit(),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: scheme.error, fontSize: 13)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.confirm ? 'Chiffrer et sauvegarder' : 'Restaurer'),
        ),
      ],
    );
  }
}
