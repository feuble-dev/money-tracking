import 'package:flutter/material.dart';

import '../../../shared/widgets/operator_avatar.dart';
import '../providers/money_providers.dart';

/// Pastille d'un compte : logo de l'opérateur (Mobile Money) ou emoji sur
/// fond coloré (compte manuel).
class AccountAvatar extends StatelessWidget {
  final MoneyAccount account;
  final double size;

  const AccountAvatar(this.account, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    if (account.isMobileMoney) {
      return OperatorAvatar(
          name: account.name, logoPath: account.logoPath, radius: size / 2);
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: account.color.withAlpha(34),
        borderRadius: BorderRadius.circular(size * 0.32),
      ),
      child: Text(account.emoji ?? '👛', style: TextStyle(fontSize: size * 0.5)),
    );
  }
}
