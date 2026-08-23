import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/operator_provider.dart';
import '../providers/transaction_type_provider.dart';
import '../models/operator_model.dart';
import '../models/sms_pattern_model.dart';
import '../widgets/sms_zone_tagger.dart';
import '../../../core/sms/sms_pattern_builder.dart';
import '../../../core/licence/licence_guard.dart';
import '../../../core/theme/app_colors.dart';

/// Écran de création/modification d'opérateur
/// En création : Stepper obligatoire (infos → SMS dépôt → SMS retrait)
/// En modification : formulaire direct
class OperatorFormScreen extends ConsumerStatefulWidget {
  final String? operatorId;

  const OperatorFormScreen({super.key, this.operatorId});

  @override
  ConsumerState<OperatorFormScreen> createState() => _OperatorFormScreenState();
}

class _OperatorFormScreenState extends ConsumerState<OperatorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _accountNumberController = TextEditingController();
  final _agentNumberController = TextEditingController();
  final _ussdDepositController = TextEditingController();
  final _ussdWithdrawController = TextEditingController();
  final _smsSenderController = TextEditingController();
  final _commissionDepotController = TextEditingController(text: '0');
  final _commissionRetraitController = TextEditingController(text: '0');
  final _smsDepotController = TextEditingController();
  final _smsRetraitController = TextEditingController();
  bool _isActive = true;
  OperatorModel? _existingOperator;
  String? _logoPath;

  int _currentStep = 0;
  List<TaggedZone> _depotZones = [];
  List<TaggedZone> _retraitZones = [];

  bool get isEditing => widget.operatorId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) _loadOperator();
  }

  void _loadOperator() {
    final operators = ref.read(operatorsProvider);
    operators.whenData((list) {
      final op = list.where((o) => o.id == widget.operatorId).firstOrNull;
      if (op != null) {
        setState(() {
          _existingOperator = op;
          _nameController.text = op.name;
          _accountNumberController.text = op.accountNumber ?? '';
          _agentNumberController.text = op.agentNumber ?? '';
          _smsSenderController.text = op.smsSender ?? '';
          _ussdDepositController.text = op.ussdDepositTemplate ?? '';
          _ussdWithdrawController.text = op.ussdWithdrawTemplate ?? '';
          _commissionDepotController.text = op.tauxCommissionDepot.toString();
          _commissionRetraitController.text = op.tauxCommissionRetrait.toString();
          _isActive = op.isActive;
          _logoPath = op.logoPath;
        });
      }
    });
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final sourcePath = result.files.single.path!;
    final appDir = await getApplicationDocumentsDirectory();
    final logosDir = Directory('${appDir.path}/operator_logos');
    await logosDir.create(recursive: true);
    final ext = p.extension(sourcePath);
    final destPath = '${logosDir.path}/op_${const Uuid().v4().substring(0, 8)}$ext';
    await File(sourcePath).copy(destPath);
    setState(() => _logoPath = destPath);
  }

  Future<void> _save() async {
    final autorise = await LicenceGuard.verifier(
      context, ActionType.configurerOperateur);
    if (!autorise || !mounted) return;

    final operatorId = _existingOperator?.id ?? const Uuid().v4();

    final operator_ = OperatorModel(
      id: operatorId,
      name: _nameController.text.trim(),
      logoPath: _logoPath,
      accountNumber: _accountNumberController.text.trim().isEmpty
          ? null : _accountNumberController.text.trim(),
      agentNumber: _agentNumberController.text.trim().isEmpty
          ? null : _agentNumberController.text.trim(),
      smsSender: _smsSenderController.text.trim().isEmpty
          ? null : _smsSenderController.text.trim(),
      ussdDepositTemplate: _ussdDepositController.text.trim().isEmpty
          ? null : _ussdDepositController.text.trim(),
      ussdWithdrawTemplate: _ussdWithdrawController.text.trim().isEmpty
          ? null : _ussdWithdrawController.text.trim(),
      isActive: _isActive,
      tauxCommissionDepot: double.tryParse(_commissionDepotController.text) ?? 0,
      tauxCommissionRetrait: double.tryParse(_commissionRetraitController.text) ?? 0,
      createdAt: _existingOperator?.createdAt,
    );

    final notifier = ref.read(operatorsProvider.notifier);
    if (_existingOperator != null) {
      await notifier.updateOperator(operator_);
    } else {
      await notifier.addOperator(operator_);

      // Sauvegarder les patterns SMS si fournis — toujours une vraie regex
      // compilée depuis les zones taguées (jamais 'auto_detect'), rattachée
      // à un operator_transaction_type_id réel, pour qu'un pattern de dépôt
      // ne puisse jamais matcher un SMS de retrait (ou d'achat de crédit).
      final senderFilter = _smsSenderController.text.trim().isEmpty
          ? null : _smsSenderController.text.trim();

      if (_smsDepotController.text.trim().isNotEmpty &&
          _depotZones.any((z) => z.fieldName == 'montant')) {
        final linkId = await TransactionTypeRepository.attachExistingTypeToOperator(
          operatorId: operatorId,
          code: 'deposit',
          ussdCode: _ussdDepositController.text.trim().isEmpty ? null : _ussdDepositController.text.trim(),
          commissionTaux: double.tryParse(_commissionDepotController.text) ?? 0,
        );
        final rawExample = _smsDepotController.text.trim();
        final regex = SmsPatternBuilder.buildRegex(rawExample, _depotZones);
        await SmsPatternRepository.savePattern(SmsPatternModel(
          id: const Uuid().v4(),
          operatorId: operatorId,
          transactionType: 'deposit',
          operatorTransactionTypeId: linkId,
          direction: 'in',
          taggedZonesJson: SmsPatternBuilder.zonesToJson(_depotZones),
          source: 'custom',
          senderFilter: senderFilter,
          rawExample: rawExample,
          patternJson: SmsPatternBuilder.zonesToJson(_depotZones),
          regexGenerated: regex,
        ));
      }
      if (_smsRetraitController.text.trim().isNotEmpty &&
          _retraitZones.any((z) => z.fieldName == 'montant')) {
        final linkId = await TransactionTypeRepository.attachExistingTypeToOperator(
          operatorId: operatorId,
          code: 'withdrawal',
          ussdCode: _ussdWithdrawController.text.trim().isEmpty ? null : _ussdWithdrawController.text.trim(),
          commissionTaux: double.tryParse(_commissionRetraitController.text) ?? 0,
        );
        final rawExample = _smsRetraitController.text.trim();
        final regex = SmsPatternBuilder.buildRegex(rawExample, _retraitZones);
        await SmsPatternRepository.savePattern(SmsPatternModel(
          id: const Uuid().v4(),
          operatorId: operatorId,
          transactionType: 'withdrawal',
          operatorTransactionTypeId: linkId,
          direction: 'out',
          taggedZonesJson: SmsPatternBuilder.zonesToJson(_retraitZones),
          source: 'custom',
          senderFilter: senderFilter,
          rawExample: rawExample,
          patternJson: SmsPatternBuilder.zonesToJson(_retraitZones),
          regexGenerated: regex,
        ));
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEditing ? 'Opérateur modifié' : 'Opérateur créé avec succès'),
          backgroundColor: AppColors.withdrawColor,
        ),
      );
      context.pop();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _accountNumberController.dispose();
    _agentNumberController.dispose();
    _ussdDepositController.dispose();
    _ussdWithdrawController.dispose();
    _smsSenderController.dispose();
    _commissionDepotController.dispose();
    _commissionRetraitController.dispose();
    _smsDepotController.dispose();
    _smsRetraitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // En modification → formulaire direct (pas de stepper)
    if (isEditing) return _buildEditForm(context);

    // En création → Stepper obligatoire
    return Scaffold(
      appBar: AppBar(title: const Text('Nouvel opérateur')),
      body: Stepper(
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
                  child: Text(_currentStep == 3 ? 'Créer l\'opérateur' : 'Suivant'),
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
          // Étape 1 — Infos générales
          Step(
            title: const Text('Informations'),
            subtitle: const Text('Nom, expéditeur SMS, logo'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildInfoStep(),
          ),
          // Étape 2 — SMS Dépôt
          Step(
            title: const Text('SMS Dépôt'),
            subtitle: const Text('Collez un SMS de dépôt'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildSmsStep(
              'deposit',
              _smsDepotController,
              _depotZones,
              (z) => setState(() => _depotZones = z),
            ),
          ),
          // Étape 3 — SMS Retrait
          Step(
            title: const Text('SMS Retrait'),
            subtitle: const Text('Collez un SMS de retrait'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: _buildSmsStep(
              'withdrawal',
              _smsRetraitController,
              _retraitZones,
              (z) => setState(() => _retraitZones = z),
            ),
          ),
          // Étape 4 — USSD + Commissions
          Step(
            title: const Text('USSD & Commissions'),
            subtitle: const Text('Templates USSD et taux'),
            isActive: _currentStep >= 3,
            content: _buildUssdCommissionStep(),
          ),
        ],
      ),
    );
  }

  void _onStepContinue() {
    switch (_currentStep) {
      case 0:
        if (_nameController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Le nom de l\'opérateur est requis')),
          );
          return;
        }
        if (_smsSenderController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Le nom expéditeur SMS est requis')),
          );
          return;
        }
        break;
      case 1:
        if (_smsDepotController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Collez un SMS de dépôt')),
          );
          return;
        }
        if (!_depotZones.any((z) => z.fieldName == 'montant')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Taguez au moins la zone "montant" dans le SMS')),
          );
          return;
        }
        break;
      case 2:
        if (_smsRetraitController.text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Collez un SMS de retrait')),
          );
          return;
        }
        if (!_retraitZones.any((z) => z.fieldName == 'montant')) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Taguez au moins la zone "montant" dans le SMS')),
          );
          return;
        }
        break;
      case 3:
        _save();
        return;
    }
    setState(() => _currentStep++);
  }

  // === Étape 1 : Infos ===
  Widget _buildInfoStep() {
    return Column(
      children: [
        // Logo
        Center(
          child: GestureDetector(
            onTap: _pickLogo,
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primaryColor.withAlpha(20),
              backgroundImage: _logoPath != null ? FileImage(File(_logoPath!)) : null,
              child: _logoPath == null
                  ? const Icon(Icons.add_a_photo, size: 28, color: AppColors.primaryColor)
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'Nom de l\'opérateur *',
            hintText: 'Ex: Orange Money',
            prefixIcon: Icon(Icons.business),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _smsSenderController,
          decoration: const InputDecoration(
            labelText: 'Nom expéditeur SMS *',
            hintText: 'Ex: OrangeMoney',
            prefixIcon: Icon(Icons.sms, color: AppColors.accentColor),
            helperText: 'Le nom exact qui apparaît comme expéditeur dans vos SMS',
            helperMaxLines: 2,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _accountNumberController,
          decoration: const InputDecoration(
            labelText: 'Numéro de compte',
            prefixIcon: Icon(Icons.account_balance),
          ),
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _agentNumberController,
          decoration: const InputDecoration(
            labelText: 'Numéro agent',
            prefixIcon: Icon(Icons.badge),
          ),
          keyboardType: TextInputType.phone,
        ),
      ],
    );
  }

  // === Étape SMS (dépôt ou retrait) — tagging réel, vraie regex (D2) ===
  Widget _buildSmsStep(
    String type,
    TextEditingController controller,
    List<TaggedZone> zones,
    ValueChanged<List<TaggedZone>> onZonesChange,
  ) {
    final isDeposit = type == 'deposit';
    final label = isDeposit ? 'dépôt' : 'retrait';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Collez un SMS de $label reçu de l\'opérateur :',
          style: const TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'SMS de $label *',
            hintText: 'Collez le SMS ici...',
            alignLabelWithHint: true,
          ),
          onChanged: (_) {
            if (zones.isNotEmpty) onZonesChange([]);
            setState(() {});
          },
        ),
        if (controller.text.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          SmsZoneTagger(
            rawExample: controller.text,
            zones: zones,
            onZonesChange: onZonesChange,
          ),
        ],
      ],
    );
  }

  // === Étape USSD + Commissions ===
  Widget _buildUssdCommissionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Templates USSD',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Variables: {numero} et {montant}',
            style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ussdDepositController,
          decoration: const InputDecoration(
            labelText: 'USSD Dépôt',
            hintText: 'Ex: *144*{numero}*{montant}#',
            prefixIcon: Icon(Icons.arrow_downward, color: AppColors.depositColor),
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _ussdWithdrawController,
          decoration: const InputDecoration(
            labelText: 'USSD Retrait',
            hintText: 'Ex: *144*{montant}#',
            prefixIcon: Icon(Icons.arrow_upward, color: AppColors.withdrawColor),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Commissions',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _commissionDepotController,
                decoration: const InputDecoration(labelText: 'Dépôt (%)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _commissionRetraitController,
                decoration: const InputDecoration(labelText: 'Retrait (%)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // === Mode édition : formulaire classique ===
  Widget _buildEditForm(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier l\'opérateur'),
        actions: [
          IconButton(
            onPressed: () => context.push('/operators/${widget.operatorId}/sms-config'),
            icon: const Icon(Icons.sms),
            tooltip: 'Configuration SMS',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primaryColor.withAlpha(20),
                  backgroundImage: _logoPath != null ? FileImage(File(_logoPath!)) : null,
                  child: _logoPath == null
                      ? const Icon(Icons.add_a_photo, size: 28, color: AppColors.primaryColor)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nom *', prefixIcon: Icon(Icons.business)),
              validator: (v) => v == null || v.trim().isEmpty ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _smsSenderController,
              decoration: const InputDecoration(labelText: 'Expéditeur SMS *', prefixIcon: Icon(Icons.sms)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _accountNumberController,
              decoration: const InputDecoration(labelText: 'N° compte', prefixIcon: Icon(Icons.account_balance)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _agentNumberController,
              decoration: const InputDecoration(labelText: 'N° agent', prefixIcon: Icon(Icons.badge)),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextFormField(
                  controller: _commissionDepotController,
                  decoration: const InputDecoration(labelText: 'Commission dépôt (%)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
                const SizedBox(width: 12),
                Expanded(child: TextFormField(
                  controller: _commissionRetraitController,
                  decoration: const InputDecoration(labelText: 'Commission retrait (%)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                )),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ussdDepositController,
              decoration: const InputDecoration(labelText: 'USSD Dépôt', hintText: '*144*{numero}*{montant}#'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ussdWithdrawController,
              decoration: const InputDecoration(labelText: 'USSD Retrait', hintText: '*144*{montant}#'),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Opérateur actif'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Enregistrer'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
