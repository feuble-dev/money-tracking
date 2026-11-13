import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/account/account_deletion.dart';

/// « Supprimer mon compte » — exigé par Google Play pour toute app qui crée
/// un compte. Explique ce qui disparaît, propose une sauvegarde d'abord, et
/// demande le mot de passe du compte.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Supprimer définitivement ?'),
        content: const Text(
            'Votre compte et toutes vos données seront effacés. On ne pourra pas les récupérer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await AccountDeletion.deleteAccount(_password.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
      return;
    }

    // Tout est effacé : l'app se ferme et repartira de l'accueil.
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (d) => AlertDialog(
        title: const Text('Compte supprimé'),
        content: const Text('Vos données ont été effacées. L\'application va se fermer.'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(d), child: const Text('OK')),
        ],
      ),
    );
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Supprimer mon compte')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text('Ce qui sera effacé', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          for (final line in const [
            'votre compte et votre mot de passe ;',
            'vos opérations, dépenses, motifs et budgets sur ce téléphone ;',
            'pour une agence : ses licences et les opérations envoyées au patron ;',
            'l\'accès de vos autres téléphones liés à ce compte.',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('•  '),
                Expanded(child: Text(line)),
              ]),
            ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.cloud_upload_outlined),
              title: const Text('Garder une copie avant ?'),
              subtitle: const Text('Faites une sauvegarde : vous pourrez la restaurer plus tard.'),
              onTap: _busy ? null : () => context.push('/settings/backup'),
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _password,
            obscureText: _obscure,
            enabled: !_busy,
            decoration: InputDecoration(
              labelText: 'Mot de passe du compte',
              helperText: 'Laissez vide si votre compte n\'a pas de mot de passe',
              errorText: _error,
              errorMaxLines: 3,
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _busy ? null : _delete,
            icon: _busy
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.delete_forever_outlined),
            label: Text(_busy ? 'Suppression…' : 'Supprimer mon compte'),
          ),
          const SizedBox(height: 12),
          Text(
            'Une connexion Internet est nécessaire. Si la suppression échoue, rien n\'est effacé.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
