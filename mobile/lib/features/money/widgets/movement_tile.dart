import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/categories/category_providers.dart';
import '../../../core/format/formats.dart';
import '../../../core/money/movement.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/amount_text.dart';
import '../providers/money_providers.dart';

/// Une ligne du fil des mouvements : revenu, dépense ou virement, quelle
/// qu'en soit la source (SMS Mobile Money ou saisie).
class MovementTile extends ConsumerWidget {
  final Movement movement;
  final bool hidden;
  final VoidCallback? onTap;

  const MovementTile(
      {super.key, required this.movement, this.hidden = false, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final cats = ref.watch(categoriesByCodeProvider).valueOrNull ?? const {};
    final accounts = ref.watch(moneyAccountsByRefProvider);
    final m = movement;
    final cat = m.category == null ? null : cats[m.category];

    final String icon;
    final Color tint;
    final String title;
    final String subtitle;
    final String sign;
    final Color amountColor;

    if (m.isTransfer) {
      final from = accounts[m.account]?.name ?? 'Compte';
      final to = accounts[m.counterAccount]?.name ?? 'Compte';
      icon = '🔄';
      tint = scheme.secondary;
      title = m.label ?? 'Virement';
      subtitle = '$from → $to';
      sign = '';
      amountColor = scheme.onSurface;
    } else {
      icon = cat?.icon ?? (m.isIncome ? '💵' : '❓');
      tint = cat?.color ?? (m.isIncome ? AppColors.withdrawColor : scheme.outline);
      title = m.label?.isNotEmpty == true
          ? m.label!
          : (cat?.label ?? (m.isIncome ? 'Revenu' : 'À catégoriser'));
      final accountName = accounts[m.account]?.name ?? '';
      subtitle = [
        if (m.label?.isNotEmpty == true && cat != null) cat.label,
        accountName,
      ].where((s) => s.isNotEmpty).join(' · ');
      sign = m.isIncome ? '+' : '−';
      amountColor = m.isIncome ? AppColors.withdrawColor : scheme.onSurface;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tint.withAlpha(30),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Text(icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle.isEmpty
                        ? AppFormats.dateTime.format(m.occurredAt)
                        : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.36),
              child: AmountText(
                hidden ? '•••••' : '$sign${AppFormats.fcfa(m.amount)}',
                alignment: AlignmentDirectional.centerEnd,
                style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700, color: amountColor),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Libellé de regroupement par jour : « Aujourd'hui », « Hier », « 12 oct. ».
String dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return "Aujourd'hui";
  if (diff == 1) return 'Hier';
  if (d.year == now.year) return AppFormats.dayMonth.format(d);
  return AppFormats.date.format(d);
}
