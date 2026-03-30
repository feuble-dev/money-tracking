import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/operator_provider.dart';
import '../models/operator_model.dart';
import '../../../core/theme/app_colors.dart';

/// Écran d'ajout/modification d'opérateur avec logo et commissions
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
  bool _isActive = true;
  OperatorModel? _existingOperator;
  String? _logoPath;

  @override
  void initState() {
    super.initState();
    if (widget.operatorId != null) {
      _loadOperator();
    }
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.single.path == null) return;

    final sourcePath = result.files.single.path!;
    final appDir = await getApplicationDocumentsDirectory();
    final logosDir = Directory('${appDir.path}/operator_logos');
    await logosDir.create(recursive: true);

    final ext = p.extension(sourcePath);
    final destName = 'op_${const Uuid().v4().substring(0, 8)}$ext';
    final destPath = '${logosDir.path}/$destName';

    await File(sourcePath).copy(destPath);
    setState(() => _logoPath = destPath);
  }

  void _removeLogo() {
    setState(() => _logoPath = null);
  }

  Future<void> _saveOperator() async {
    if (!_formKey.currentState!.validate()) return;

    final operator_ = OperatorModel(
      id: _existingOperator?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      logoPath: _logoPath,
      accountNumber: _accountNumberController.text.trim().isEmpty
          ? null
          : _accountNumberController.text.trim(),
      agentNumber: _agentNumberController.text.trim().isEmpty
          ? null
          : _agentNumberController.text.trim(),
      smsSender: _smsSenderController.text.trim().isEmpty
          ? null
          : _smsSenderController.text.trim(),
      ussdDepositTemplate: _ussdDepositController.text.trim().isEmpty
          ? null
          : _ussdDepositController.text.trim(),
      ussdWithdrawTemplate: _ussdWithdrawController.text.trim().isEmpty
          ? null
          : _ussdWithdrawController.text.trim(),
      isActive: _isActive,
      tauxCommissionDepot:
          double.tryParse(_commissionDepotController.text) ?? 0,
      tauxCommissionRetrait:
          double.tryParse(_commissionRetraitController.text) ?? 0,
      createdAt: _existingOperator?.createdAt,
    );

    final notifier = ref.read(operatorsProvider.notifier);
    if (_existingOperator != null) {
      await notifier.updateOperator(operator_);
    } else {
      await notifier.addOperator(operator_);
    }

    if (mounted) context.pop();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.operatorId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier l\'opérateur' : 'Nouvel opérateur'),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: () => _showSmsConfig(),
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
            // === Logo ===
            Center(
              child: GestureDetector(
                onTap: _pickLogo,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 48,
                      backgroundColor: AppColors.primaryColor.withAlpha(20),
                      backgroundImage: _logoPath != null
                          ? FileImage(File(_logoPath!))
                          : null,
                      child: _logoPath == null
                          ? const Icon(Icons.add_a_photo,
                              size: 32, color: AppColors.primaryColor)
                          : null,
                    ),
                    if (_logoPath != null)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: _removeLogo,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Appuyez pour ajouter un logo',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 20),

            // === Nom ===
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom de l\'opérateur *',
                hintText: 'Ex: Orange Money',
                prefixIcon: Icon(Icons.business),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nom requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _accountNumberController,
              decoration: const InputDecoration(
                labelText: 'Numéro de compte',
                hintText: 'Numéro du compte agent',
                prefixIcon: Icon(Icons.account_balance),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _agentNumberController,
              decoration: const InputDecoration(
                labelText: 'Numéro agent',
                hintText: 'Numéro d\'identification agent',
                prefixIcon: Icon(Icons.badge),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),

            // === Expéditeur SMS ===
            TextFormField(
              controller: _smsSenderController,
              decoration: const InputDecoration(
                labelText: 'Nom expéditeur SMS',
                hintText: 'Ex: OrangeMoney, MOOV-BF',
                prefixIcon: Icon(Icons.sms, color: AppColors.accentColor),
                helperText: 'Copiez exactement le nom qui apparaît comme expéditeur dans vos SMS',
                helperMaxLines: 2,
              ),
            ),
            const SizedBox(height: 24),

            // === Commissions ===
            Text(
              'Commissions',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Pourcentage de commission sur chaque transaction',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _commissionDepotController,
                    decoration: const InputDecoration(
                      labelText: 'Commission dépôt (%)',
                      prefixIcon: Icon(Icons.arrow_downward,
                          color: AppColors.depositColor),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _commissionRetraitController,
                    decoration: const InputDecoration(
                      labelText: 'Commission retrait (%)',
                      prefixIcon: Icon(Icons.arrow_upward,
                          color: AppColors.withdrawColor),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // === Templates USSD ===
            Text(
              'Templates USSD',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Utilisez {numero} et {montant} comme variables',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ussdDepositController,
              decoration: const InputDecoration(
                labelText: 'USSD Dépôt',
                hintText: 'Ex: *144*{numero}*{montant}#',
                prefixIcon: Icon(Icons.arrow_downward,
                    color: AppColors.depositColor),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ussdWithdrawController,
              decoration: const InputDecoration(
                labelText: 'USSD Retrait',
                hintText: 'Ex: *144*{montant}#',
                prefixIcon: Icon(Icons.arrow_upward,
                    color: AppColors.withdrawColor),
              ),
            ),
            const SizedBox(height: 24),
            SwitchListTile(
              title: const Text('Opérateur actif'),
              subtitle: const Text(
                  'Les opérateurs inactifs ne reçoivent pas de transactions'),
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              activeTrackColor: AppColors.withdrawColor,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _saveOperator,
              icon: const Icon(Icons.save),
              label: Text(isEditing ? 'Modifier' : 'Créer l\'opérateur'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSmsConfig() {
    context.push('/operators/${widget.operatorId}/sms-config');
  }
}
