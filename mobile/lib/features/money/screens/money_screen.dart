import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/money/money_entry.dart';
import '../../../shared/providers/privacy_provider.dart';
import '../../../shared/widgets/animated_amount.dart';
import '../../../shared/widgets/fade_slide_in.dart';
import '../../../shared/widgets/main_shell.dart';
import '../../../shared/widgets/section_header.dart';
import '../providers/money_providers.dart';
import '../widgets/account_card.dart';
import '../widgets/entry_sheet.dart';
import '../widgets/movement_list.dart';
import '../widgets/wallet_form_sheet.dart';

/// « Mon argent » (compte Particulier) : où est mon argent en ce moment —
/// portefeuilles Mobile Money (suivis par SMS) ET comptes tenus à la main
/// (espèces, banque, épargne…) — et tous mes mouvements au même endroit.
class MoneyScreen extends ConsumerWidget {
  const MoneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hidden = !ref.watch(balanceVisibleProvider);
    final accountsAsync = ref.watch(moneyAccountsProvider);
    final movementsAsync = ref.watch(movementsProvider(null));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Mon argent'),
        actions: [
          IconButton(
            tooltip: hidden ? 'Afficher les montants' : 'Masquer les montants',
            icon: Icon(hidden ? Icons.visibility_off : Icons.visibility),
            onPressed: () => ref.read(balanceVisibleProvider.notifier).toggle(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'money_add',
        onPressed: () => showEntrySheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => invalidateMoney(ref),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _TotalCard(hidden: hidden),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _QuickActions(),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
              sliver: SliverToBoxAdapter(child: SectionHeader('Mes comptes')),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 132,
                child: accountsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Erreur : $e')),
                  data: (accounts) => ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: accounts.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) {
                      if (i == accounts.length) {
                        return AddAccountCard(
                            onTap: () => showWalletForm(context));
                      }
                      final a = accounts[i];
                      return FadeSlideIn(
                        index: i,
                        child: AccountCard(
                          account: a,
                          hidden: hidden,
                          onTap: () => context.push(
                              '/money/account/${Uri.encodeComponent(a.ref.raw)}'),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(
                  child: SectionHeader('Derniers mouvements')),
            ),
            movementsAsync.when(
              loading: () => const SliverToBoxAdapter(
                  child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()))),
              error: (e, _) =>
                  SliverToBoxAdapter(child: Center(child: Text('Erreur : $e'))),
              data: (moves) => moves.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
                        child: Text(
                          'Vos dépenses et revenus apparaîtront ici : ceux '
                          'détectés par SMS, et ceux que vous ajoutez '
                          '(espèces, banque…).',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      sliver: MovementSlivers(movements: moves, hidden: hidden),
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 96)),
          ],
        ),
      ),
    );
  }
}

/// Total de tout l'argent, avec la répartition par compte en une barre.
class _TotalCard extends ConsumerWidget {
  final bool hidden;
  const _TotalCard({required this.hidden});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final total = ref.watch(netWorthProvider);
    final accounts = (ref.watch(moneyAccountsProvider).valueOrNull ?? const [])
        .where((a) => (a.balance ?? 0) > 0)
        .toList();
    final positive = accounts.fold(0.0, (s, a) => s + a.balance!);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tout mon argent',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Colors.white70)),
          const SizedBox(height: 6),
          AnimatedAmount(
            total,
            hidden: hidden,
            style: theme.textTheme.headlineMedium?.copyWith(
                color: Colors.white, fontWeight: FontWeight.w800),
          ),
          if (accounts.length > 1 && !hidden) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 8,
                child: Row(
                  children: [
                    for (final a in accounts)
                      Expanded(
                        flex: ((a.balance! / positive) * 1000).round().clamp(1, 1000),
                        child: ColoredBox(color: a.color),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final a in accounts)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: a.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${a.name} ${(a.balance! / positive * 100).round()} %',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String label, Color color, EntryKind kind) {
      return Expanded(
        child: Material(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showEntrySheet(context, kind: kind),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Icon(icon, color: color),
                  const SizedBox(height: 6),
                  Text(label,
                      style: TextStyle(
                          color: color, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        action(Icons.north_east, 'Dépense', scheme.error, EntryKind.expense),
        const SizedBox(width: 10),
        action(Icons.south_west, 'Revenu', const Color(0xFF2E7D32),
            EntryKind.income),
        const SizedBox(width: 10),
        action(Icons.swap_horiz, 'Virement', scheme.primary, EntryKind.transfer),
      ],
    );
  }
}
