import 'package:flutter/material.dart';
import '../../../core/sms/sms_pattern_builder.dart';
import '../../../core/theme/app_colors.dart';

const _fieldNames = [
  'montant',
  'numero_client',
  'operator_transaction_id',
  'operator_reference',
  'solde',
  'nom_client',
];

/// Tagging d'un SMS exemple par sélection de texte (start/end/fieldName),
/// équivalent mobile de web/components/admin/SmsPatternTagger.tsx — même
/// principe (sélection → tag), pour que le pattern produit soit une vraie
/// regex compilée (SmsPatternBuilder.buildRegex), jamais un heuristique
/// approximatif. Partagé entre l'écran de config SMS d'un opérateur du
/// catalogue et la création d'un opérateur custom, pour ne pas dupliquer
/// cette logique de tagging comme l'était l'ancien moteur de matching.
class SmsZoneTagger extends StatefulWidget {
  final String rawExample;
  final List<TaggedZone> zones;
  final ValueChanged<List<TaggedZone>> onZonesChange;

  const SmsZoneTagger({
    super.key,
    required this.rawExample,
    required this.zones,
    required this.onZonesChange,
  });

  @override
  State<SmsZoneTagger> createState() => _SmsZoneTaggerState();
}

class _SmsZoneTaggerState extends State<SmsZoneTagger> {
  late TextEditingController _controller;
  String _pendingField = _fieldNames.first;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.rawExample);
  }

  @override
  void didUpdateWidget(covariant SmsZoneTagger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rawExample != widget.rawExample) {
      _controller.text = widget.rawExample;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _tagSelection() {
    final selection = _controller.selection;
    if (!selection.isValid || selection.isCollapsed) return;
    final start = selection.start;
    final end = selection.end;
    final value = widget.rawExample.substring(start, end);
    if (value.trim().isEmpty) return;

    widget.onZonesChange([
      ...widget.zones,
      TaggedZone(start: start, end: end, fieldName: _pendingField, value: value),
    ]);
  }

  void _removeZone(int index) {
    final updated = [...widget.zones]..removeAt(index);
    widget.onZonesChange(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _pendingField,
                items: _fieldNames
                    .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                    .toList(),
                onChanged: (v) => setState(() => _pendingField = v ?? _pendingField),
                decoration: const InputDecoration(isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _tagSelection,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accentColor),
              child: const Text('Taguer'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'Sélectionnez une portion du texte ci-dessous (appui long puis étirez), puis appuyez sur "Taguer".',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.withAlpha(20),
            borderRadius: BorderRadius.circular(10),
          ),
          child: TextField(
            controller: _controller,
            readOnly: true,
            maxLines: null,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.all(10),
            ),
          ),
        ),
        if (widget.zones.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildHighlightedPreview(),
          const SizedBox(height: 10),
          ...widget.zones.asMap().entries.map((e) {
            final zone = e.value;
            return Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Colors.grey.withAlpha(40)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 12, color: Colors.black87),
                        children: [
                          TextSpan(text: '${zone.fieldName} ', style: const TextStyle(fontWeight: FontWeight.bold)),
                          TextSpan(text: '— "${zone.value}"'),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    onPressed: () => _removeZone(e.key),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildHighlightedPreview() {
    final sorted = [...widget.zones]..sort((a, b) => a.start.compareTo(b.start));
    final spans = <TextSpan>[];
    var cursor = 0;
    for (final zone in sorted) {
      if (zone.start > cursor) {
        spans.add(TextSpan(text: widget.rawExample.substring(cursor, zone.start)));
      }
      spans.add(TextSpan(
        text: widget.rawExample.substring(zone.start, zone.end),
        style: TextStyle(
          backgroundColor: AppColors.accentColor.withAlpha(35),
          color: AppColors.accentColor,
          fontWeight: FontWeight.bold,
        ),
      ));
      cursor = zone.end > cursor ? zone.end : cursor;
    }
    if (cursor < widget.rawExample.length) {
      spans.add(TextSpan(text: widget.rawExample.substring(cursor)));
    }
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.black87),
        children: spans,
      ),
    );
  }
}
