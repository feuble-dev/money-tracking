import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format/amount_input_formatter.dart';
import '../../../core/money/money_repository.dart';
import '../../../core/money/wallet.dart';
import '../providers/money_providers.dart';

/// Création ou modification d'un compte tenu à la main.
Future<bool?> showWalletForm(BuildContext context, {Wallet? editing}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _WalletForm(editing: editing),
  );
}

class _WalletForm extends ConsumerStatefulWidget {
  final Wallet? editing;
  const _WalletForm({this.editing});

  @override
  ConsumerState<_WalletForm> createState() => _WalletFormState();
}

class _WalletFormState extends ConsumerState<_WalletForm> {
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  late final _initial = TextEditingController(
      text: widget.editing == null || widget.editing!.initialBalance == 0
          ? ''
          : formatAmountInput(widget.editing!.initialBalance));
  late WalletKind _kind = widget.editing?.kind ?? WalletKind.bank;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _initial.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim().isEmpty ? _kind.label : _name.text.trim();
    final initial = parseAmountInput(_initial.text) ?? 0;
    setState(() => _saving = true);
    final w = widget.editing;
    if (w == null) {
      await MoneyRepository.createWallet(
          name: name, kind: _kind, initialBalance: initial);
    } else {
      final kindChanged = w.kind != _kind;
      await MoneyRepository.updateWallet(Wallet(
        id: w.id,
        name: name,
        kind: _kind,
        icon: kindChanged ? _kind.defaultIcon : w.icon,
        colorHex: kindChanged ? _kind.defaultColor : w.colorHex,
        initialBalance: initial,
        sortOrder: w.sortOrder,
      ));
    }
    invalidateMoney(ref);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.editing == null ? 'Nouveau compte' : 'Modifier le compte',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final k in WalletKind.values)
                  ChoiceChip(
                    avatar: Text(k.defaultIcon),
                    label: Text(k.label),
                    selected: _kind == k,
                    onSelected: (_) => setState(() => _kind = k),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Nom',
                hintText: switch (_kind) {
                  WalletKind.cash => 'Ex. Espèces, Porte-monnaie',
                  WalletKind.bank => 'Ex. Coris Bank, Ecobank',
                  WalletKind.savings => 'Ex. Tontine du quartier',
                  WalletKind.other => 'Ex. Caisse de la boutique',
                },
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _initial,
              keyboardType: TextInputType.number,
              inputFormatters: const [AmountInputFormatter()],
              decoration: const InputDecoration(
                labelText: 'Solde de départ',
                suffixText: 'FCFA',
                helperText: 'Ce que contient ce compte aujourd\'hui',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(widget.editing == null ? 'Créer le compte' : 'Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
