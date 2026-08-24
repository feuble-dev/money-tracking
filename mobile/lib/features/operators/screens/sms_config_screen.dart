import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/sms/sms_pattern_builder.dart';
import '../../../core/theme/app_colors.dart';
import '../models/sms_pattern_model.dart';
import '../providers/operator_provider.dart';
import '../providers/transaction_type_provider.dart';
import '../widgets/sms_zone_tagger.dart';

/// Écran de configuration SMS — tagging réel de zones (montant, numéro
/// client, etc.) sur un SMS exemple, rattaché à un type de transaction
/// précis de cet opérateur (operator_transaction_type_id). Produit toujours
/// une vraie regex compilée (SmsPatternBuilder), jamais l'ancien
/// 'auto_detect' heuristique — c'est ce dernier qui permettait à un SMS
/// d'achat de crédit d'être pris pour un transfert, faute de discriminant
/// réel entre types de transaction.
class SmsConfigScreen extends ConsumerStatefulWidget {
  final String operatorId;

  const SmsConfigScreen({super.key, required this.operatorId});

  @override
  ConsumerState<SmsConfigScreen> createState() => _SmsConfigScreenState();
}

class _SmsConfigScreenState extends ConsumerState<SmsConfigScreen> {
  final _smsController = TextEditingController();
  final _testSmsController = TextEditingController();

  OperatorTransactionTypeOption? _selectedType;
  String? _directionOverride; // null = sens par défaut du type
  List<TaggedZone> _zones = [];
  Map<String, String>? _testResult;
  int _currentStep = 0;

  // Non-null quand on modifie un pattern existant (chargé via _editPattern)
  // plutôt que d'en créer un nouveau — _savePattern met à jour en place.
  String? _editingPatternId;
  String? _editingSource;

  @override
  void dispose() {
    _smsController.dispose();
    _testSmsController.dispose();
    super.dispose();
  }

  Future<void> _createCustomType() async {
    final labelController = TextEditingController();
    String direction = 'in';
    final created = await showDialog<OperatorTransactionTypeOption>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Nouveau type de transaction'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: labelController,
                decoration: const InputDecoration(labelText: 'Libellé (ex: Paiement marchand)'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'in', label: Text('Entrant')),
                  ButtonSegment(value: 'out', label: Text('Sortant')),
                ],
                selected: {direction},
                onSelectionChanged: (v) => setDialogState(() => direction = v.first),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              onPressed: () async {
                if (labelController.text.trim().isEmpty) return;
                final option = await TransactionTypeRepository.createCustomTypeForOperator(
                  operatorId: widget.operatorId,
                  label: labelController.text.trim(),
                  defaultDirection: direction,
                );
                if (ctx.mounted) Navigator.pop(ctx, option);
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    if (created != null) {
      ref.invalidate(operatorTransactionTypesProvider(widget.operatorId));
      setState(() => _selectedType = created);
    }
  }

  void _runTest() {
    final regex = SmsPatternBuilder.buildRegex(_smsController.text, _zones);
    setState(() {
      _testResult = SmsPatternBuilder.parseSms(_testSmsController.text, regex);
    });
  }

  /// Charge un pattern existant dans le formulaire pour le modifier — sans
  /// ça, la seule action possible sur un pattern déjà créé était de le
  /// supprimer, jamais de corriger sa regex (ex: une zone mal taguée).
  Future<void> _editPattern(SmsPatternModel p) async {
    final types = await ref.read(operatorTransactionTypesProvider(widget.operatorId).future);
    OperatorTransactionTypeOption? matchedType;
    for (final t in types) {
      if (t.linkId == p.operatorTransactionTypeId) {
        matchedType = t;
        break;
      }
    }
    if (!mounted) return;
    setState(() {
      _editingPatternId = p.id;
      _editingSource = p.source;
      _smsController.text = p.rawExample;
      _zones = p.taggedZonesJson != null
          ? SmsPatternBuilder.zonesFromJson(p.taggedZonesJson!)
          : [];
      _selectedType = matchedType;
      _directionOverride =
          (matchedType != null && p.direction != matchedType.defaultDirection)
              ? p.direction
              : null;
      _testSmsController.clear();
      _testResult = null;
      _currentStep = 0;
    });
  }

  void _startNewPattern() {
    setState(() {
      _editingPatternId = null;
      _editingSource = null;
      _selectedType = null;
      _directionOverride = null;
      _zones = [];
      _smsController.clear();
      _testSmsController.clear();
      _testResult = null;
      _currentStep = 0;
    });
  }

  Future<void> _savePattern() async {
    final type = _selectedType;
    if (type == null) return;
    final regex = SmsPatternBuilder.buildRegex(_smsController.text, _zones);
    final editingId = _editingPatternId;

    final pattern = SmsPatternModel(
      id: editingId ?? const Uuid().v4(),
      operatorId: widget.operatorId,
      transactionType: type.code,
      operatorTransactionTypeId: type.linkId,
      direction: _directionOverride ?? type.defaultDirection,
      taggedZonesJson: SmsPatternBuilder.zonesToJson(_zones),
      // Un pattern catalogue modifié par l'agent devient un override local
      // (D6) — un futur resync du catalogue ne doit jamais écraser cette
      // correction, il ne touche que les patterns encore source='catalog'.
      source: editingId != null
          ? (_editingSource == 'catalog' ? 'catalog_overridden' : _editingSource ?? 'custom')
          : 'custom',
      rawExample: _smsController.text,
      patternJson: SmsPatternBuilder.zonesToJson(_zones),
      regexGenerated: regex,
    );

    if (editingId != null) {
      await SmsPatternRepository.updatePattern(pattern);
    } else {
      await SmsPatternRepository.savePattern(pattern);
    }
    ref.invalidate(smsPatternsProvider(widget.operatorId));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(editingId != null ? 'Pattern SMS modifié' : 'Pattern SMS sauvegardé'),
          backgroundColor: AppColors.withdrawColor,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final patternsAsync = ref.watch(smsPatternsProvider(widget.operatorId));
    final typesAsync = ref.watch(operatorTransactionTypesProvider(widget.operatorId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_editingPatternId != null ? 'Modifier le pattern' : 'Configuration SMS'),
      ),
      body: Column(
        children: [
          patternsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (patterns) {
              if (patterns.isEmpty) return const SizedBox.shrink();
              return Container(
                height: 56,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: patterns.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          avatar: const Icon(Icons.add, size: 16),
                          label: const Text('Nouveau', style: TextStyle(fontSize: 12)),
                          onPressed: _startNewPattern,
                        ),
                      );
                    }
                    final p = patterns[index - 1];
                    final selected = p.id == _editingPatternId;
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(p.transactionType, style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        onPressed: () => _editPattern(p),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () async {
                          await SmsPatternRepository.deletePattern(p.id);
                          if (_editingPatternId == p.id) _startNewPattern();
                          ref.invalidate(smsPatternsProvider(widget.operatorId));
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
          Expanded(
            child: Stepper(
              currentStep: _currentStep,
              onStepContinue: () => _onStepContinue(typesAsync.value ?? []),
              onStepCancel: _currentStep > 0 ? () => setState(() => _currentStep--) : null,
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child: Text(_currentStep == 3 ? 'Sauvegarder' : 'Suivant'),
                      ),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        TextButton(onPressed: details.onStepCancel, child: const Text('Retour')),
                      ],
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Type & SMS exemple'),
                  subtitle: const Text('Choisissez le type visé et collez un SMS'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: _buildStep1(typesAsync),
                ),
                Step(
                  title: const Text('Tagger les zones'),
                  subtitle: const Text('Montant obligatoire, le reste optionnel'),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  content: _buildStep2(),
                ),
                Step(
                  title: const Text('Test'),
                  subtitle: const Text('Vérifiez avec un second SMS'),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                  content: _buildStep3(),
                ),
                Step(
                  title: const Text('Sauvegarder'),
                  isActive: _currentStep >= 3,
                  content: _buildStep4(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1(AsyncValue<List<OperatorTransactionTypeOption>> typesAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        typesAsync.when(
          loading: () => const CircularProgressIndicator(),
          error: (_, _) => const Text('Erreur de chargement des types'),
          data: (types) {
            if (types.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Aucun type de transaction activé pour cet opérateur.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _createCustomType,
                    icon: const Icon(Icons.add),
                    label: const Text('Créer un type'),
                  ),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedType?.linkId,
                  decoration: const InputDecoration(labelText: 'Type de transaction *'),
                  items: types
                      .map((t) => DropdownMenuItem(
                            value: t.linkId,
                            child: Text('${t.label} (${t.defaultDirection == 'in' ? 'entrant' : 'sortant'})'),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() {
                    _selectedType = types.firstWhere((t) => t.linkId == v);
                  }),
                ),
                const SizedBox(height: 4),
                TextButton.icon(
                  onPressed: _createCustomType,
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nouveau type'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _smsController,
          maxLines: 6,
          onChanged: (_) => setState(() => _zones = []),
          decoration: const InputDecoration(
            labelText: 'SMS exemple *',
            hintText: 'Collez ici un SMS de confirmation de l\'opérateur...',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    if (_smsController.text.trim().isEmpty) {
      return const Text('Retournez à l\'étape précédente pour coller un SMS.');
    }
    return SmsZoneTagger(
      rawExample: _smsController.text,
      zones: _zones,
      onZonesChange: (z) => setState(() => _zones = z),
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _testSmsController,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'SMS de test',
            hintText: 'Collez un autre SMS du même opérateur...',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _runTest,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Tester'),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryLight),
        ),
        if (_testResult != null) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (_testResult!.isEmpty ? Colors.orange : AppColors.withdrawColor).withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _testResult!.isEmpty
                ? const Text('Aucun champ détecté sur ce SMS de test.', style: TextStyle(color: Colors.orange))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _testResult!.entries
                        .map((e) => Text('${e.key}: ${e.value}', style: const TextStyle(fontFamily: 'monospace')))
                        .toList(),
                  ),
          ),
        ],
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryRow('Type', _selectedType?.label ?? '-'),
        _summaryRow('Zones taguées', _zones.map((z) => z.fieldName).join(', ')),
        const SizedBox(height: 12),
        DropdownButtonFormField<String?>(
          initialValue: _directionOverride,
          decoration: InputDecoration(
            labelText: 'Sens (optionnel - défaut : ${_selectedType?.defaultDirection == 'in' ? 'entrant' : 'sortant'})',
          ),
          items: const [
            DropdownMenuItem(value: null, child: Text('Utiliser le sens par défaut')),
            DropdownMenuItem(value: 'in', child: Text('Entrant')),
            DropdownMenuItem(value: 'out', child: Text('Sortant')),
          ],
          onChanged: (v) => setState(() => _directionOverride = v),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _onStepContinue(List<OperatorTransactionTypeOption> types) {
    switch (_currentStep) {
      case 0:
        if (_selectedType == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Choisissez un type de transaction')),
          );
          return;
        }
        if (_smsController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez coller un SMS exemple')),
          );
          return;
        }
        break;
      case 1:
        if (!_zones.any((z) => z.fieldName == 'montant')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Taguez au moins la zone "montant"')),
          );
          return;
        }
        break;
      case 3:
        _savePattern();
        return;
    }

    setState(() {
      if (_currentStep < 3) _currentStep++;
    });
  }
}
