import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/format/amount_input_formatter.dart';
import '../../../core/format/formats.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../../shared/widgets/section_header.dart';
import '../data/cash_closing_repository.dart';

/// Clôture du jour (Agence) : combien d'espèces l'agent devrait avoir, face
/// à ce qu'il a compté. Calcul : départ + entrées − sorties du jour.
class CashClosingScreen extends StatefulWidget {
  const CashClosingScreen({super.key});

  @override
  State<CashClosingScreen> createState() => _CashClosingScreenState();
}

class _CashClosingScreenState extends State<CashClosingScreen> {
  final _opening = TextEditingController();
  final _counted = TextEditingController();
  final _note = TextEditingController();

  DateTime _day = _today();
  CashDay? _summary;
  CashClosing? _saved;
  List<CashClosing> _history = const [];
  bool _saving = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _opening.dispose();
    _counted.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final summary = await CashClosingRepository.summarize(_day);
    final saved = await CashClosingRepository.forDay(_day);
    final opening = saved?.opening ?? await CashClosingRepository.suggestedOpening(_day);
    final history = await CashClosingRepository.history();
    if (!mounted) return;
    setState(() {
      _summary = summary;
      _saved = saved;
      _history = history;
      _opening.text = formatAmountInput(opening);
      _counted.text = saved == null ? '' : formatAmountInput(saved.counted);
      _note.text = saved?.note ?? '';
    });
  }

  double get _openingValue => parseAmountInput(_opening.text) ?? 0;
  double? get _countedValue =>
      _counted.text.trim().isEmpty ? null : parseAmountInput(_counted.text);

  Future<void> _save() async {
    final counted = _countedValue;
    if (counted == null) return;
    setState(() => _saving = true);
    await CashClosingRepository.save(
      day: _day,
      opening: _openingValue,
      counted: counted,
      note: _note.text,
    );
    HapticFeedback.lightImpact();
    await _load();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clôture enregistrée')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = _summary;
    final yesterday = _today().subtract(const Duration(days: 1));

    return Scaffold(
      appBar: AppBar(title: const Text('Clôture du jour')),
      body: s == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Wrap(spacing: 8, children: [
                  for (final (label, d) in [("Aujourd'hui", _today()), ('Hier', yesterday)])
                    ChoiceChip(
                      label: Text(label),
                      selected: _day == d,
                      onSelected: (_) {
                        setState(() {
                          _day = d;
                          _summary = null;
                        });
                        _load();
                      },
                    ),
                ]),
                const SizedBox(height: 16),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        _Line(
                          label: 'Espèces au départ',
                          trailing: SizedBox(
                            width: 160,
                            child: TextField(
                              controller: _opening,
                              textAlign: TextAlign.end,
                              keyboardType: TextInputType.number,
                              inputFormatters: const [AmountInputFormatter()],
                              decoration: const InputDecoration(isDense: true, suffixText: 'FCFA'),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ),
                        _Line(
                          label: '+ Dépôts reçus',
                          value: '+ ${AppFormats.fcfa(s.totalIn)}',
                          color: const Color(0xFF2E7D32),
                        ),
                        _Line(
                          label: '− Retraits payés',
                          value: '− ${AppFormats.fcfa(s.totalOut)}',
                          color: theme.colorScheme.error,
                        ),
                        const Divider(height: 24),
                        _Line(
                          label: 'Vous devriez avoir',
                          value: AppFormats.fcfa(s.expected(_openingValue)),
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    '${s.operations} opération${s.operations > 1 ? 's' : ''} · '
                    '${AppFormats.fcfa(s.commissions)} de commissions',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),
                Text('J\'ai compté', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                TextField(
                  controller: _counted,
                  keyboardType: TextInputType.number,
                  inputFormatters: const [AmountInputFormatter()],
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                  decoration: const InputDecoration(
                    hintText: '0',
                    suffixText: 'FCFA',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 12),
                if (_countedValue != null)
                  _GapBanner(gap: _countedValue! - s.expected(_openingValue)),
                const SizedBox(height: 12),
                TextField(
                  controller: _note,
                  decoration: const InputDecoration(
                    labelText: 'Note (facultatif)',
                    hintText: 'Ex. : billet de 2 000 abîmé mis de côté',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _countedValue == null || _saving ? null : _save,
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                  child: Text(_saved == null ? 'Enregistrer la clôture' : 'Mettre à jour la clôture'),
                ),
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 28),
                  const SectionHeader('Dernières clôtures'),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final c in _history)
                          ListTile(
                            dense: true,
                            title: Text(AppFormats.date.format(DateTime.parse(c.day))),
                            subtitle: Text('Compté ${AppFormats.fcfa(c.counted)}'),
                            trailing: _GapChip(gap: c.gap),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String? value;
  final Widget? trailing;
  final Color? color;
  final bool bold;

  const _Line({required this.label, this.value, this.trailing, this.color, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 17 : 15,
      color: color,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
              flex: 3,
              child: Text(label, style: TextStyle(fontWeight: bold ? FontWeight.w700 : null))),
          const SizedBox(width: 12),
          trailing ??
              Expanded(
                flex: 4,
                child: AmountText(value ?? '', style: style, alignment: AlignmentDirectional.centerEnd),
              ),
        ],
      ),
    );
  }
}

/// L'écart en mots simples, pas en signe.
class _GapBanner extends StatelessWidget {
  final double gap;
  const _GapBanner({required this.gap});

  @override
  Widget build(BuildContext context) {
    final ok = gap.abs() < 1;
    final (color, icon, text) = ok
        ? (const Color(0xFF2E7D32), Icons.check_circle_outline, 'Le compte est bon.')
        : gap < 0
            ? (Colors.orange.shade800, Icons.error_outline, 'Il manque ${AppFormats.fcfa(-gap)}.')
            : (Colors.blue.shade700, Icons.info_outline, 'Il y a ${AppFormats.fcfa(gap)} en trop.');
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(22),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _GapChip extends StatelessWidget {
  final double gap;
  const _GapChip({required this.gap});

  @override
  Widget build(BuildContext context) {
    if (gap.abs() < 1) {
      return const Icon(Icons.check_circle, color: Color(0xFF2E7D32), size: 20);
    }
    final missing = gap < 0;
    return Text(
      '${missing ? '−' : '+'} ${AppFormats.fcfa(gap.abs())}',
      style: TextStyle(
        fontWeight: FontWeight.w700,
        color: missing ? Colors.orange.shade800 : Colors.blue.shade700,
      ),
    );
  }
}
