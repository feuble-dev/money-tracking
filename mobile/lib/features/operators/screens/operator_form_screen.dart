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

  /// `_logoPath` peut être une URL distante (opérateur importé du
  /// catalogue, déjà pourvu d'un logo admin) ou un chemin de fichier local
  /// (nouveau logo choisi via _pickLogo) — FileImage seul plantait
  /// silencieusement (aucune image) sur le premier cas.
  ImageProvider? get _logoImageProvider {
    if (_logoPath == null) return null;
    if (_logoPath!.startsWith('http://') || _logoPath!.startsWith('https://')) {
      return NetworkImage(_logoPath!);
    }
    return FileImage(File(_logoPath!));
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

  /// Attache un type de transaction à cet opérateur — soit un type global
  /// déjà connu (catalogue ou custom d'un autre opérateur, D3), soit un
  /// tout nouveau type custom propre à cet opérateur.
  Future<void> _attachType(BuildContext context) async {
    final allTypes = await ref.read(allTransactionTypesProvider.future);
    final attached = await ref.read(operatorTransactionTypesProvider(widget.operatorId!).future);
    final attachedIds = attached.map((t) => t.transactionTypeId).toSet();
    final available = allTypes.where((t) => !attachedIds.contains(t['id'])).toList();

    if (!context.mounted) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Attacher un type'),
        children: [
          ...available.map((t) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, 'existing:${t['id']}'),
                child: Text('${t['label']} '
                    '(${t['default_direction'] == 'in' ? 'entrant' : 'sortant'})'),
              )),
          if (available.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text('Tous les types connus sont déjà attachés.',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
            ),
          const Divider(),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, 'new'),
            child: const Row(
              children: [
                Icon(Icons.add, size: 18, color: AppColors.accentColor),
                SizedBox(width: 8),
                Text('Nouveau type custom'),
              ],
            ),
          ),
        ],
      ),
    );
    if (choice == null || !mounted || !context.mounted) return;

    if (choice == 'new') {
      await _createNewCustomType(context);
      return;
    }

    final typeId = choice.split(':')[1];
    final type = allTypes.firstWhere((t) => t['id'] == typeId);
    await TransactionTypeRepository.attachExistingTypeToOperator(
      operatorId: widget.operatorId!,
      code: type['code'] as String,
    );
    if (mounted) {
      ref.invalidate(operatorTransactionTypesProvider(widget.operatorId!));
    }
  }

  Future<void> _createNewCustomType(BuildContext context) async {
    final labelController = TextEditingController();
    String direction = 'in';
    final created = await showDialog<bool>(
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
                await TransactionTypeRepository.createCustomTypeForOperator(
                  operatorId: widget.operatorId!,
                  label: labelController.text.trim(),
                  defaultDirection: direction,
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
    if (created == true && mounted) {
      ref.invalidate(operatorTransactionTypesProvider(widget.operatorId!));
    }
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
              backgroundImage: _logoImageProvider,
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
                  backgroundImage: _logoImageProvider,
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
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Types de transaction',
                    style: Theme.of(context).textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                TextButton.icon(
                  onPressed: () => _attachType(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Type'),
                ),
              ],
            ),
            Text(
              'USSD et commission sont propres à chaque type pour cet opérateur.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 8),
            Consumer(builder: (context, ref, _) {
              final typesAsync =
                  ref.watch(operatorTransactionTypesProvider(widget.operatorId!));
              return typesAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Text('Erreur: $e'),
                data: (types) {
                  if (types.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('Aucun type activé - ajoutez-en un.',
                          style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    );
                  }
                  return Column(
                    children: types
                        .map((t) => _TypeEditRow(
                              option: t,
                              onChanged: () => ref.invalidate(
                                  operatorTransactionTypesProvider(widget.operatorId!)),
                            ))
                        .toList(),
                  );
                },
              );
            }),
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

/// Une ligne éditable pour un type de transaction attaché à l'opérateur —
/// USSD + commission propres à CETTE paire (opérateur, type), plus de
/// champ unique "USSD Dépôt"/"USSD Retrait" au niveau de l'opérateur (D3).
class _TypeEditRow extends StatefulWidget {
  final OperatorTransactionTypeOption option;
  final VoidCallback onChanged;

  const _TypeEditRow({required this.option, required this.onChanged});

  @override
  State<_TypeEditRow> createState() => _TypeEditRowState();
}

class _TypeEditRowState extends State<_TypeEditRow> {
  late final TextEditingController _ussdController;
  late final TextEditingController _commissionController;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _ussdController = TextEditingController(text: widget.option.ussdCode ?? '');
    _commissionController =
        TextEditingController(text: widget.option.commissionTaux.toString());
  }

  @override
  void dispose() {
    _ussdController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final commission = double.tryParse(_commissionController.text) ?? 0;
    await TransactionTypeRepository.updateLink(
      linkId: widget.option.linkId,
      ussdCode: _ussdController.text.trim().isEmpty ? null : _ussdController.text.trim(),
      commissionTaux: commission,
    );
    if (mounted) setState(() => _dirty = false);
    widget.onChanged();
  }

  Future<void> _detach() async {
    await TransactionTypeRepository.detachFromOperator(widget.option.linkId);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.option.defaultDirection == 'in'
        ? AppColors.depositColor
        : AppColors.withdrawColor;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  widget.option.defaultDirection == 'in'
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
                  size: 18,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(widget.option.label,
                      style: TextStyle(fontWeight: FontWeight.w600, color: color)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                  tooltip: 'Détacher',
                  onPressed: _detach,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _ussdController,
                    decoration: const InputDecoration(
                      labelText: 'USSD',
                      hintText: '*144*{numero}*{montant}#',
                      isDense: true,
                    ),
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _commissionController,
                    decoration: const InputDecoration(labelText: 'Commission %', isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() => _dirty = true),
                  ),
                ),
              ],
            ),
            if (_dirty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: _save, child: const Text('Enregistrer')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
