import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money/account_ref.dart';
import '../../../core/money/money_entry.dart';
import '../../../core/money/money_repository.dart';
import '../../../shared/providers/privacy_provider.dart';
import '../../../shared/widgets/animated_amount.dart';
import '../providers/money_providers.dart';
import '../widgets/account_avatar.dart';
import '../widgets/entry_sheet.dart';
import '../widgets/movement_list.dart';
import '../widgets/wallet_form_sheet.dart';

/// Un compte : solde et mouvements. Un compte manuel se modifie/archive ;
/// un portefeuille Mobile Money est en lecture seule (solde annoncé par
/// les SMS).
class AccountScreen extends ConsumerWidget {
  final AccountRef account;
  const AccountScreen({super.key, required this.account});

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirer ce compte ?'),
        content: const Text(
            "Ses opérations restent dans vos statistiques ; il n'apparaîtra "
            'simplement plus dans vos comptes.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Retirer')),
        ],
      ),
    );
    if (ok != true) return;
    await MoneyRepository.removeWallet(account.id);
    invalidateMoney(ref);
    if (context.mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hidden = !ref.watch(balanceVisibleProvider);
    final acc = ref.watch(moneyAccountsByRefProvider)[account];
    final moves = ref.watch(movementsProvider(account));

    if (acc == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(acc.name),
        actions: [
          if (acc.wallet != null)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') showWalletForm(context, editing: acc.wallet);
                if (v == 'remove') _remove(context, ref);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Modifier')),
                PopupMenuItem(value: 'remove', child: Text('Retirer')),
              ],
            ),
        ],
      ),
      floatingActionButton: acc.isMobileMoney
          ? FloatingActionButton.extended(
              heroTag: 'acc_transfer',
              onPressed: () => showEntrySheet(context,
                  kind: EntryKind.transfer, account: account),
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Virement'),
            )
          : FloatingActionButton.extended(
              heroTag: 'acc_add',
              onPressed: () => showEntrySheet(context, account: account),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter'),
            ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                children: [
                  AccountAvatar(acc, size: 52),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Solde',
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                        acc.balance == null
                            ? Text('Inconnu',
                                style: theme.textTheme.headlineSmall)
                            : AnimatedAmount(
                                acc.balance!,
                                hidden: hidden,
                                style: theme.textTheme.headlineSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                        if (acc.isMobileMoney)
                          Text('Annoncé par le dernier SMS de l\'opérateur',
                              style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          moves.when(
            loading: () => const SliverToBoxAdapter(
                child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()))),
            error: (e, _) =>
                SliverToBoxAdapter(child: Center(child: Text('Erreur : $e'))),
            data: (list) => list.isEmpty
                ? const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: Text('Aucun mouvement pour l\'instant')),
                    ),
                  )
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    sliver: MovementSlivers(movements: list, hidden: hidden),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}
