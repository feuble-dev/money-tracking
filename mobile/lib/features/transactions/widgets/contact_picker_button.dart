import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../core/permissions/permission_service.dart';

/// Bouton "carnet d'adresses" à placer en `suffixIcon` d'un champ numéro :
/// ouvre le sélecteur de contacts natif et renvoie un numéro nettoyé via
/// [onPicked]. En cas de refus de permission ou d'annulation, ne fait rien
/// (l'utilisateur garde la saisie manuelle).
class ContactPickerButton extends StatelessWidget {
  final ValueChanged<String> onPicked;

  const ContactPickerButton({super.key, required this.onPicked});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.contacts_outlined),
      tooltip: 'Choisir dans les contacts',
      onPressed: () async {
        final phone = await pickContactPhone(context);
        if (phone != null && phone.isNotEmpty) onPicked(phone);
      },
    );
  }
}

/// Demande la permission contacts, ouvre le sélecteur natif, et renvoie le
/// numéro choisi (nettoyé au format BF). `null` si permission refusée,
/// sélection annulée, ou contact sans numéro.
Future<String?> pickContactPhone(BuildContext context) async {
  final granted = await PermissionService.requestContactsPermission();
  if (!context.mounted) return null;
  if (!granted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Autorisez l\'accès aux contacts pour choisir un numéro'),
      ),
    );
    return null;
  }

  final picked = await FlutterContacts.openExternalPick();
  if (picked == null || !context.mounted) return null;

  final full = await FlutterContacts.getContact(picked.id, withProperties: true);
  final numbers = (full?.phones ?? const [])
      .map((p) => _normalizeBfPhone(p.number))
      .where((n) => n.isNotEmpty)
      .toSet()
      .toList();

  if (numbers.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce contact n\'a pas de numéro')),
      );
    }
    return null;
  }
  if (numbers.length == 1) return numbers.first;

  if (!context.mounted) return null;
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('Numéro de ${full?.displayName ?? 'ce contact'}',
                style: Theme.of(ctx).textTheme.titleMedium),
          ),
          ...numbers.map((n) => ListTile(
                leading: const Icon(Icons.phone),
                title: Text(n),
                onTap: () => Navigator.pop(ctx, n),
              )),
        ],
      ),
    ),
  );
}

String _normalizeBfPhone(String raw) {
  var d = raw.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.startsWith('00226')) {
    d = d.substring(5);
  } else if (d.startsWith('226') && d.length > 8) {
    d = d.substring(3);
  }
  return d;
}
