import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/sms/sms_field_extractor.dart';
import '../../../core/theme/app_colors.dart';
import '../models/sms_pattern_model.dart';
import '../providers/operator_provider.dart';

/// Champs extractibles avec leur label et icône
const _fieldLabels = {
  'montant': ('Montant', Icons.attach_money, AppColors.depositColor),
  'numero_client': ('N. Client', Icons.phone_android, AppColors.primaryColor),
  'operator_transaction_id': ('ID Trans.', Icons.bookmark, AppColors.accentColor),
  'solde': ('Solde', Icons.account_balance_wallet, Colors.teal),
  'nom_client': ('Nom Client', Icons.person, Colors.purple),
};

/// Écran de configuration SMS simplifié avec auto-détection
class SmsConfigScreen extends ConsumerStatefulWidget {
  final String operatorId;

  const SmsConfigScreen({super.key, required this.operatorId});

  @override
  ConsumerState<SmsConfigScreen> createState() => _SmsConfigScreenState();
}

class _SmsConfigScreenState extends ConsumerState<SmsConfigScreen> {
  final _smsController = TextEditingController();
  final _testSmsController = TextEditingController();
  String _transactionType = 'deposit';
  int _currentStep = 0;

  // Résultats de l'auto-détection
  Map<String, String> _detectedFields = {};
  Map<String, String> _testDetectedFields = {};

  @override
  void dispose() {
    _smsController.dispose();
    _testSmsController.dispose();
    super.dispose();
  }

  /// Lance l'auto-détection sur le SMS exemple
  void _autoDetect() {
    final sms = _smsController.text.trim();
    if (sms.isEmpty) return;

    final detected = SmsFieldExtractor.extractAll(sms);
    final type = SmsFieldExtractor.detectTransactionType(sms);

    setState(() {
      _detectedFields = detected;
      if (type != null) _transactionType = type;
    });
  }

  /// Teste sur un autre SMS
  void _runTest() {
    final sms = _testSmsController.text.trim();
    if (sms.isEmpty) return;

    setState(() {
      _testDetectedFields = SmsFieldExtractor.extractAll(sms);
    });
  }

  @override
  Widget build(BuildContext context) {
    final patternsAsync = ref.watch(smsPatternsProvider(widget.operatorId));

    return Scaffold(
      appBar: AppBar(title: const Text('Configuration SMS')),
      body: Column(
        children: [
          // Patterns existants
          patternsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (patterns) {
              if (patterns.isEmpty) return const SizedBox.shrink();
              return Container(
                height: 80,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: patterns.length,
                  itemBuilder: (context, index) {
                    final p = patterns[index];
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(
                          '${p.transactionType == 'deposit' ? 'Dépôt' : 'Retrait'} — ${p.senderFilter ?? 'Tous'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () async {
                          await SmsPatternRepository.deletePattern(p.id);
                          ref.invalidate(smsPatternsProvider(widget.operatorId));
                        },
                        backgroundColor: p.transactionType == 'deposit'
                            ? AppColors.depositColor.withAlpha(30)
                            : AppColors.withdrawColor.withAlpha(30),
                      ),
                    );
                  },
                ),
              );
            },
          ),

          // Stepper
          Expanded(
            child: Stepper(
              currentStep: _currentStep,
              onStepContinue: _onStepContinue,
              onStepCancel: _currentStep > 0
                  ? () => setState(() => _currentStep--)
                  : null,
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child: Text(
                          _currentStep == 3 ? 'Sauvegarder' : 'Suivant',
                        ),
                      ),
                      if (_currentStep > 0) ...[
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Retour'),
                        ),
                      ],
                    ],
                  ),
                );
              },
              steps: [
                // Étape 1 — Coller le SMS
                Step(
                  title: const Text('SMS exemple'),
                  subtitle: const Text('Collez un SMS de l\'opérateur'),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                  content: _buildStep1(),
                ),

                // Étape 2 — Auto-détection
                Step(
                  title: const Text('Détection automatique'),
                  subtitle: const Text('Vérifiez les champs détectés'),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                  content: _buildStep2(),
                ),

                // Étape 3 — Test
                Step(
                  title: const Text('Test'),
                  subtitle: const Text('Testez avec un autre SMS'),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                  content: _buildStep3(),
                ),

                // Étape 4 — Sauvegarder
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

  /// Étape 1 — Type + SMS exemple
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'deposit',
              label: Text('Dépôt'),
              icon: Icon(Icons.arrow_downward),
            ),
            ButtonSegment(
              value: 'withdrawal',
              label: Text('Retrait'),
              icon: Icon(Icons.arrow_upward),
            ),
          ],
          selected: {_transactionType},
          onSelectionChanged: (v) =>
              setState(() => _transactionType = v.first),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _smsController,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'SMS exemple *',
            hintText: 'Collez ici un SMS de confirmation de l\'opérateur...',
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  /// Étape 2 — Résultat de l'auto-détection
  Widget _buildStep2() {
    if (_detectedFields.isEmpty) {
      return Column(
        children: [
          const Text('Appuyez sur "Détecter" pour analyser le SMS.'),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _autoDetect,
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Détecter automatiquement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Résultats
        ..._fieldLabels.entries.map((entry) {
          final fieldName = entry.key;
          final (label, icon, color) = entry.value;
          final value = _detectedFields[fieldName];
          final found = value != null;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: found
                  ? AppColors.withdrawColor.withAlpha(15)
                  : Colors.grey.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: found
                    ? AppColors.withdrawColor.withAlpha(40)
                    : Colors.grey.withAlpha(40),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  found ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: found ? AppColors.withdrawColor : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                const Spacer(),
                if (found)
                  Flexible(
                    child: Text(
                      value,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.w600,
                          fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (!found)
                  const Text('Non détecté',
                      style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontStyle: FontStyle.italic)),
              ],
            ),
          );
        }),

        const SizedBox(height: 12),
        // Bouton re-détecter
        OutlinedButton.icon(
          onPressed: _autoDetect,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Re-détecter'),
        ),

        if (!_detectedFields.containsKey('montant'))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Le montant n\'a pas été détecté. Vérifiez que le SMS est bien un SMS de transaction.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Étape 3 — Test avec un autre SMS
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
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryLight,
          ),
        ),
        if (_testDetectedFields.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.withdrawColor.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.withdrawColor.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: AppColors.withdrawColor, size: 20),
                    SizedBox(width: 8),
                    Text('Valeurs extraites :',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.withdrawColor)),
                  ],
                ),
                const SizedBox(height: 8),
                ..._testDetectedFields.entries.map((e) {
                  final fieldInfo = _fieldLabels[e.key];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Icon(fieldInfo?.$2 ?? Icons.label,
                            size: 16, color: fieldInfo?.$3),
                        const SizedBox(width: 8),
                        Text('${fieldInfo?.$1 ?? e.key}: ',
                            style: const TextStyle(fontWeight: FontWeight.w500)),
                        Flexible(
                          child: Text(e.value,
                              style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
        if (_testDetectedFields.isEmpty &&
            _testSmsController.text.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.withdrawColor.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              children: [
                Icon(Icons.error_outline,
                    color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Text('Aucun champ détecté',
                    style: TextStyle(color: Colors.orange)),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Étape 4 — Résumé et sauvegarde
  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _summaryRow('Type',
            _transactionType == 'deposit' ? 'Dépôt' : 'Retrait'),
        _summaryRow('Champs détectés',
            _detectedFields.keys.map((k) => _fieldLabels[k]?.$1 ?? k).join(', ')),
        const SizedBox(height: 8),
        const Text(
          'Le pattern sera utilisé pour détecter automatiquement les transactions depuis les SMS entrants.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
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
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _onStepContinue() {
    switch (_currentStep) {
      case 0:
        if (_smsController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Veuillez coller un SMS exemple')),
          );
          return;
        }
        // Auto-détecter automatiquement à l'étape 2
        _autoDetect();
        break;
      case 1:
        if (!_detectedFields.containsKey('montant')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Le montant doit être détecté pour continuer')),
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

  Future<void> _savePattern() async {
    // Sauvegarder les patterns utilisés pour cette détection
    final patternJson = jsonEncode(SmsFieldExtractor.fieldPatterns);

    final pattern = SmsPatternModel(
      id: const Uuid().v4(),
      operatorId: widget.operatorId,
      transactionType: _transactionType,
      senderFilter: null,
      rawExample: _smsController.text,
      patternJson: patternJson,
      regexGenerated: 'auto_detect', // Plus de regex monolithique
    );

    await SmsPatternRepository.savePattern(pattern);
    ref.invalidate(smsPatternsProvider(widget.operatorId));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration SMS sauvegardée'),
          backgroundColor: AppColors.withdrawColor,
        ),
      );
      context.pop();
    }
  }
}
