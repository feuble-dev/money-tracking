import 'package:flutter/material.dart';

import '../../../shared/widgets/amount_text.dart';
import '../../../core/format/formats.dart';
import '../providers/money_providers.dart';
import 'account_avatar.dart';

/// Carte compacte d'un compte (liste horizontale de « Mon argent »).
class AccountCard extends StatelessWidget {
  final MoneyAccount account;
  final bool hidden;
  final VoidCallback? onTap;

  const AccountCard(
      {super.key, required this.account, this.hidden = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final balance = account.balance;
    return SizedBox(
      width: 156,
      child: Material(
        color: scheme.surfaceContainerHighest.withAlpha(120),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AccountAvatar(account, size: 34),
                    const Spacer(),
                    if (account.isMobileMoney)
                      Icon(Icons.sms_outlined,
                          size: 15, color: scheme.onSurfaceVariant),
                  ],
                ),
                const Spacer(),
                Text(
                  account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                AmountText(
                  hidden
                      ? '•••••'
                      : balance == null
                          ? '—'
                          : AppFormats.fcfa(balance),
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dernière carte de la liste : créer un compte.
class AddAccountCard extends StatelessWidget {
  final VoidCallback onTap;
  const AddAccountCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 120,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: scheme.primary),
                const SizedBox(height: 6),
                Text('Nouveau compte',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: scheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
