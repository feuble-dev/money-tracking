import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money_repository.dart';
import '../../../core/money/movement.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import 'entry_sheet.dart';
import 'movement_tile.dart';

/// Mouvements groupés par jour, sous forme de slivers (à insérer dans un
/// CustomScrollView). Toucher une saisie manuelle l'ouvre en modification ;
/// une transaction Mobile Money ouvre sa catégorisation.
class MovementSlivers extends ConsumerWidget {
  final List<Movement> movements;
  final bool hidden;

  const MovementSlivers(
      {super.key, required this.movements, this.hidden = false});

  Future<void> _open(BuildContext context, Movement m) async {
    if (m.isManual) {
      final entry = await MoneyRepository.entry(m.id);
      if (entry != null && context.mounted) {
        await showEntrySheet(context, editing: entry);
      }
    } else {
      context.push('/categorize/${m.id}');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Liste aplatie [en-tête de jour, lignes…] pour un SliverList paresseux.
    final items = <Object>[];
    String? lastDay;
    for (final m in movements) {
      final day = dayLabel(m.occurredAt);
      if (day != lastDay) {
        items.add(day);
        lastDay = day;
      }
      items.add(m);
    }
    final theme = Theme.of(context);
    return SliverList.builder(
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item is String) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 4),
            child: Text(item,
                style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600)),
          );
        }
        final m = item as Movement;
        return FadeSlideIn(
          index: i,
          child: MovementTile(
            movement: m,
            hidden: hidden,
            onTap: () => _open(context, m),
          ),
        );
      },
    );
  }
}
