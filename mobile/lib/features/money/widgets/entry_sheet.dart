import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/categories/category_providers.dart';
import '../../../core/categories/expense_category.dart';
import '../../../core/format/amount_input_formatter.dart';
import '../../../core/format/formats.dart';
import '../../../core/money/account_ref.dart';
import '../../../core/money/money_entry.dart';
import '../../../core/money/money_repository.dart';
import '../../categories/widgets/category_picker_sheet.dart';
import '../providers/money_providers.dart';
import 'account_avatar.dart';

/// Saisie rapide d'une dépense, d'un revenu ou d'un virement — ou
/// modification d'une opération existante ([editing]). Renvoie `true` si
/// quelque chose a été enregistré ou supprimé.
Future<bool?> showEntrySheet(
  BuildContext context, {
  EntryKind kind = EntryKind.expense,
  AccountRef? account,
  MoneyEntry? editing,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _EntrySheet(
      initialKind: editing?.kind ?? kind,
      initialAccount: editing?.account ?? account,
      editing: editing,
    ),
  );
}

class _EntrySheet extends ConsumerStatefulWidget {
  final EntryKind initialKind;
  final AccountRef? initialAccount;
  final MoneyEntry? editing;

  const _EntrySheet(
      {required this.initialKind, this.initialAccount, this.editing});

  @override
  ConsumerState<_EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends ConsumerState<_EntrySheet> {
  late EntryKind _kind = widget.initialKind;
  late final _amount = TextEditingController(
      text: widget.editing == null ? '' : formatAmountInput(widget.editing!.amount));
  late final _label = TextEditingController(text: widget.editing?.label ?? '');
  late final _note = TextEditingController(text: widget.editing?.note ?? '');
  late AccountRef? _account = widget.initialAccount;
  late AccountRef? _counter = widget.editing?.counterAccount;
  late String? _category = widget.editing?.category;
  late DateTime _date = widget.editing?.occurredAt ?? DateTime.now();
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.editing != null;

  /// Dépense/revenu : seuls les comptes manuels (le Mobile Money est suivi
  /// par SMS). Virement : tous.
  List<MoneyAccount> _choices(List<MoneyAccount> all) => _kind ==
          EntryKind.transfer
      ? all
      : all.where((a) => !a.isMobileMoney).toList();

  /// Compte choisi, ou le premier disponible par défaut.
  AccountRef? _effectiveAccount(List<MoneyAccount> choices) =>
      choices.any((a) => a.ref == _account)
          ? _account
          : (choices.isEmpty ? null : choices.first.ref);
  String get _direction => _kind == EntryKind.income ? 'in' : 'out';

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = parseAmountInput(_amount.text) ?? 0;
    final account = _effectiveAccount(
        _choices(ref.read(moneyAccountsProvider).valueOrNull ?? const []));
    String? error;
    if (amount <= 0) {
      error = 'Indiquez un montant';
    } else if (account == null) {
      error = 'Choisissez un compte';
    } else if (_kind == EntryKind.transfer &&
        (_counter == null || _counter == account)) {
      error = 'Choisissez deux comptes différents';
    } else if (_kind != EntryKind.transfer && _category == null) {
      error = 'Choisissez un motif';
    }
    if (error != null) {
      HapticFeedback.mediumImpact();
      setState(() => _error = error);
      return;
    }

    setState(() => _saving = true);
    if (_isEdit) {
      await MoneyRepository.updateEntry(MoneyEntry(
        id: widget.editing!.id,
        kind: _kind,
        account: account!,
        counterAccount: _kind == EntryKind.transfer ? _counter : null,
        amount: amount,
        category: _kind == EntryKind.transfer ? kCategoryInternal : _category,
        label: _label.text.trim().isEmpty ? null : _label.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        occurredAt: _date,
        linkedTransactionId: widget.editing!.linkedTransactionId,
      ));
    } else {
      await MoneyRepository.addEntry(
        kind: _kind,
        account: account!,
        counterAccount: _counter,
        amount: amount,
        category: _category,
        label: _label.text,
        note: _note.text,
        occurredAt: _date,
      );
    }
    HapticFeedback.lightImpact();
    invalidateMoney(ref);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer cette opération ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await MoneyRepository.deleteEntry(widget.editing!.id);
    invalidateMoney(ref);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2018),
      lastDate: DateTime.now(),
    );
    if (d != null) {
      setState(() => _date = DateTime(d.year, d.month, d.day,
          _date.hour, _date.minute));
    }
  }

  Future<void> _moreCategories() async {
    final choice = await showCategoryPicker(context,
        direction: _direction, current: _category);
    if (choice != null) setState(() => _category = choice.code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accounts = ref.watch(moneyAccountsProvider).valueOrNull ?? const [];
    final choices = _choices(accounts);
    final account = _effectiveAccount(choices);

    final cats = (ref.watch(expenseCategoriesProvider).valueOrNull ?? const [])
        .where((c) => c.code != kCategoryInternal && c.matchesDirection(_direction))
        .toList();
    final shownCats = [
      ...cats.take(7),
      // La catégorie choisie via « Plus » reste visible.
      if (_category != null && !cats.take(7).any((c) => c.code == _category))
        ...cats.where((c) => c.code == _category),
    ];

    final accent = switch (_kind) {
      EntryKind.expense => scheme.error,
      EntryKind.income => const Color(0xFF2E7D32),
      EntryKind.transfer => scheme.primary,
    };

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<EntryKind>(
              segments: const [
                ButtonSegment(value: EntryKind.expense, label: Text('Dépense')),
                ButtonSegment(value: EntryKind.income, label: Text('Revenu')),
                ButtonSegment(value: EntryKind.transfer, label: Text('Virement')),
              ],
              selected: {_kind},
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: accent.withAlpha(36),
                selectedForegroundColor: accent,
              ),
              onSelectionChanged: (s) => setState(() {
                _kind = s.first;
                _error = null;
                if (_category != null &&
                    !cats.any((c) => c.code == _category)) {
                  _category = null;
                }
              }),
            ),
            const SizedBox(height: 20),
            // Montant au centre, gros et sans cadre : c'est l'information
            // principale de la saisie.
            TextField(
              controller: _amount,
              autofocus: !_isEdit,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              inputFormatters: const [AmountInputFormatter()],
              style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800, color: accent),
              decoration: InputDecoration.collapsed(
                hintText: '0',
                hintStyle: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800, color: scheme.outlineVariant),
              ).copyWith(
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 4),
            Text('FCFA',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: scheme.onSurfaceVariant, letterSpacing: 1.5)),
            const SizedBox(height: 20),
            _fieldLabel(_kind == EntryKind.transfer ? 'Depuis' : 'Compte'),
            _AccountChoices(
              accounts: choices,
              selected: account,
              onSelected: (r) => setState(() => _account = r),
            ),
            if (_kind == EntryKind.transfer) ...[
              const SizedBox(height: 12),
              _fieldLabel('Vers'),
              _AccountChoices(
                accounts: accounts.where((a) => a.ref != account).toList(),
                selected: _counter,
                onSelected: (r) => setState(() => _counter = r),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Un retrait ou un dépôt Mobile Money sera rapproché '
                  'automatiquement de son SMS : il ne comptera ni comme '
                  'une dépense ni comme un revenu.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              _fieldLabel('Motif'),
              SizedBox(
                height: 92,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in shownCats)
                      _CategoryBubble(
                        icon: c.icon,
                        label: c.label,
                        color: c.color,
                        selected: _category == c.code,
                        onTap: () => setState(() {
                          _category = c.code;
                          _error = null;
                        }),
                      ),
                    _CategoryBubble(
                      icon: '⋯',
                      label: 'Plus de motifs',
                      color: scheme.outline,
                      selected: false,
                      onTap: _moreCategories,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _label,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: switch (_kind) {
                  EntryKind.expense => 'Pour quoi / à qui ? (facultatif)',
                  EntryKind.income => 'De qui ? (facultatif)',
                  EntryKind.transfer => 'Libellé (facultatif)',
                },
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    children: [
                      _dateChip("Aujourd'hui", DateTime.now()),
                      _dateChip(
                          'Hier', DateTime.now().subtract(const Duration(days: 1))),
                      ActionChip(
                        avatar: const Icon(Icons.event, size: 18),
                        label: Text(_isOtherDay
                            ? AppFormats.date.format(_date)
                            : 'Autre jour'),
                        onPressed: _pickDate,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note (facultatif)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _error == null
                  ? const SizedBox(height: 16)
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(_error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.error)),
                    ),
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: accent,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              child: Text(_isEdit ? 'Enregistrer' : 'Ajouter',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            if (_isEdit) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Supprimer'),
                style: TextButton.styleFrom(foregroundColor: scheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool get _isOtherDay {
    final now = DateTime.now();
    return !_sameDay(_date, now) &&
        !_sameDay(_date, now.subtract(const Duration(days: 1)));
  }

  Widget _dateChip(String label, DateTime day) => ChoiceChip(
        label: Text(label),
        selected: _sameDay(_date, day),
        onSelected: (_) => setState(() => _date = DateTime(
            day.year, day.month, day.day, DateTime.now().hour,
            DateTime.now().minute)),
      );

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 2),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _AccountChoices extends StatelessWidget {
  final List<MoneyAccount> accounts;
  final AccountRef? selected;
  final ValueChanged<AccountRef> onSelected;

  const _AccountChoices(
      {required this.accounts, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return Text('Aucun compte disponible',
          style: TextStyle(color: Theme.of(context).colorScheme.error));
    }
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: accounts.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final a = accounts[i];
          return ChoiceChip(
            avatar: AccountAvatar(a, size: 22),
            label: Text(a.name),
            selected: a.ref == selected,
            onSelected: (_) => onSelected(a.ref),
          );
        },
      ),
    );
  }
}

/// Motif sélectionnable : emoji dans une pastille, libellé sur deux lignes.
class _CategoryBubble extends StatelessWidget {
  final String icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryBubble({
    required this.icon,
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 78,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? color.withAlpha(40) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? color : Colors.transparent, width: 1.5),
          ),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: color.withAlpha(30), shape: BoxShape.circle),
                child: Text(icon, style: const TextStyle(fontSize: 19)),
              ),
              const SizedBox(height: 6),
              Text(label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, height: 1.15)),
            ],
          ),
        ),
      ),
    );
  }
}
