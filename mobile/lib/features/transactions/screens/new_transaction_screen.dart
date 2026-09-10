import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/onboarding/onboarding_state.dart';
import '../../../core/sms/commission_calculator.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ussd/ussd_launcher.dart';
import '../widgets/contact_picker_button.dart';
import '../../caisse/providers/caisse_provider.dart';
import '../../clients/models/client_model.dart';
import '../../clients/providers/client_provider.dart';
import '../../operators/models/operator_model.dart';
import '../../operators/providers/operator_provider.dart';
import '../../operators/providers/transaction_type_provider.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../../../core/licence/licence_guard.dart';

/// Écran de nouvelle transaction — opérateur puis type d'abord (D3) : plus
/// de dichotomie dépôt/retrait figée dans la route (voir l'ancien
/// `/transactions/new/:type`). Une fois l'opérateur choisi, les types
/// disponibles viennent de ses `operator_transaction_types` (catalogue ou
/// custom) — chacun porte son propre code USSD et sa propre commission,
/// il n'y a plus de "USSD dépôt"/"USSD retrait" au niveau opérateur.
class NewTransactionScreen extends ConsumerStatefulWidget {
  const NewTransactionScreen({super.key});

  @override
  ConsumerState<NewTransactionScreen> createState() =>
      _NewTransactionScreenState();
}

class _NewTransactionScreenState extends ConsumerState<NewTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _cnibController = TextEditingController();

  OperatorModel? _selectedOperator;
  OperatorTransactionTypeOption? _selectedType;
  ClientModel? _selectedClient;
  bool _isNewClient = false;
  List<ClientModel> _suggestions = [];
  Timer? _debounce;
  final _currencyFormat =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  bool get _isEntrant => _selectedType?.defaultDirection == 'in';

  @override
  void dispose() {
    _debounce?.cancel();
    _phoneController.dispose();
    _amountController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cnibController.dispose();
    super.dispose();
  }

  void _searchClients(String query) {
    _debounce?.cancel();
    if (query.length < 2) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await ref.read(clientSuggestionsProvider(query).future);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        _selectedClient = null;
        _isNewClient = results.isEmpty && query.length >= 8;
      });
    });
  }

  void _selectClient(ClientModel client) {
    setState(() {
      _selectedClient = client;
      _phoneController.text = client.phoneNumber;
      _suggestions = [];
      _isNewClient = false;
    });
  }

  double? get _amountValue => double.tryParse(
      _amountController.text.replaceAll(RegExp(r'[^\d]'), ''));

  Future<String?> _ensureClientCreated() async {
    final phone = _phoneController.text.trim();
    if (_selectedClient != null) return _selectedClient!.id;
    if (_isNewClient &&
        _firstNameController.text.isNotEmpty &&
        _lastNameController.text.isNotEmpty) {
      final newClient = ClientModel(
        id: const Uuid().v4(),
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
        phoneNumber: phone,
        cnibNumber: _cnibController.text.trim().isEmpty
            ? null
            : _cnibController.text.trim(),
        operatorId: _selectedOperator!.id,
      );
      await ref.read(clientsProvider.notifier).addClient(newClient);
      return newClient.id;
    }
    return null;
  }

  bool get _isAgence =>
      ref.read(accountTypeProvider).valueOrNull != 'particulier';

  /// Lance le USSD — PAS de création de transaction ici, c'est le SMS
  /// entrant qui la crée automatiquement (sms_processing_pipeline.dart).
  Future<void> _launchUssd() async {
    final autorise = await LicenceGuard.verifier(context, ActionType.lancerUSSD);
    if (!autorise || !mounted) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOperator == null || _selectedType == null) return;

    final template = _selectedType!.ussdCode;
    if (template == null || template.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pas de code USSD configuré pour ce type')),
      );
      return;
    }

    final phone = _phoneController.text.trim();
    final amount = _amountValue;
    if (amount == null || amount <= 0) return;

    // La gestion des clients ne concerne que les comptes Agence (D18) — un
    // compte Particulier ne fait que lancer le USSD.
    if (_isAgence) await _ensureClientCreated();

    final launched = await UssdLauncher.launch(
      template: template,
      numero: phone,
      montant: amount,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            launched
                ? 'USSD lancé - ${_currencyFormat.format(amount)}. '
                    'La transaction sera créée automatiquement à la réception du SMS.'
                : 'Échec du lancement USSD',
          ),
          backgroundColor: launched ? AppColors.primaryColor : Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
      context.pop();
    }
  }

  /// Création manuelle — DORMANT (D18) : le bouton est retiré de l'UI pour
  /// l'instant, le `+` ne fait plus que lancer un USSD. Code conservé pour
  /// une réactivation future.
  // ignore: unused_element
  Future<void> _createManual() async {
    final autorise = await LicenceGuard.verifier(
        context, ActionType.creerTransactionManuelle);
    if (!autorise || !mounted) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOperator == null || _selectedType == null) return;

    final amount = _amountValue;
    if (amount == null || amount <= 0) return;

    final phone = _phoneController.text.trim();
    final commission =
        CommissionCalculator.compute(amount: amount, commissionTaux: _selectedType!.commissionTaux);

    final clientId = await _ensureClientCreated();
    final clientName = _selectedClient?.fullName ??
        (_isNewClient
            ? '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}'
            : null);

    final transaction = TransactionModel(
      id: const Uuid().v4(),
      operatorId: _selectedOperator!.id,
      clientId: clientId,
      transactionType: _selectedType!.code,
      transactionTypeId: _selectedType!.transactionTypeId,
      direction: _selectedType!.defaultDirection,
      amount: amount,
      commission: commission,
      clientPhone: phone,
      clientName: clientName,
      source: 'manual',
    );

    await ref.read(transactionsProvider.notifier).addTransaction(transaction);

    await ref.read(caissesProvider.notifier).updateSoldeAfterTransaction(
      operatorId: _selectedOperator!.id,
      amount: amount,
      direction: _selectedType!.defaultDirection,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedType!.label} de ${_currencyFormat.format(amount)} créé manuellement',
          ),
          backgroundColor:
              _isEntrant ? AppColors.depositColor : AppColors.withdrawColor,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final operatorsAsync = ref.watch(operatorsProvider);
    // La capture d'un client (nom/prénom/CNIB) ne concerne que les comptes
    // Agence (D18) — un compte Particulier ne fait que lancer le USSD.
    final isAgence =
        ref.watch(accountTypeProvider).valueOrNull != 'particulier';
    final typesAsync = _selectedOperator != null
        ? ref.watch(operatorTransactionTypesProvider(_selectedOperator!.id))
        : null;
    final headerColor = _selectedType == null
        ? AppColors.primaryColor
        : (_isEntrant ? AppColors.depositColor : AppColors.withdrawColor);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle transaction'),
        backgroundColor: headerColor,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // === Étape 1 : Opérateur ===
            Text('Opérateur',
                style: Theme.of(context)
                    .textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            operatorsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Erreur: $e'),
              data: (operators) {
                final activeOps = operators.where((o) => o.isActive).toList();
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: activeOps.map((op) {
                    final isSelected = _selectedOperator?.id == op.id;
                    return ChoiceChip(
                      label: Text(op.name),
                      selected: isSelected,
                      onSelected: (v) => setState(() {
                        _selectedOperator = v ? op : null;
                        _selectedType = null;
                      }),
                      selectedColor: AppColors.primaryColor.withAlpha(50),
                    );
                  }).toList(),
                );
              },
            ),

            // === Étape 2 : Type (dépend de l'opérateur) ===
            if (_selectedOperator != null) ...[
              const SizedBox(height: 20),
              Text('Type de transaction',
                  style: Theme.of(context)
                      .textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              typesAsync!.when(
                loading: () => const CircularProgressIndicator(),
                error: (e, _) => Text('Erreur: $e'),
                data: (types) {
                  if (types.isEmpty) {
                    return Text(
                      'Aucun type activé pour cet opérateur - configurez-le depuis "Opérateurs".',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: types.map((t) {
                      final isSelected = _selectedType?.linkId == t.linkId;
                      final color = t.defaultDirection == 'in'
                          ? AppColors.depositColor
                          : AppColors.withdrawColor;
                      return ChoiceChip(
                        avatar: Icon(
                          t.defaultDirection == 'in'
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          size: 18,
                          color: isSelected ? Colors.white : color,
                        ),
                        label: Text(t.label),
                        selected: isSelected,
                        selectedColor: color,
                        onSelected: (v) =>
                            setState(() => _selectedType = v ? t : null),
                      );
                    }).toList(),
                  );
                },
              ),
            ],

            // Type sélectionné sans code USSD → lancement impossible (D18).
            if (_selectedType != null &&
                (_selectedType!.ussdCode == null ||
                    _selectedType!.ussdCode!.isEmpty)) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ce type n\'a pas de code USSD configuré — impossible '
                        'de lancer. Ajoutez-le depuis "Opérateurs".',
                        style: TextStyle(
                            fontSize: 13, color: Colors.orange.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Numéro client
            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Numéro du client *',
                hintText: '70 12 34 56',
                prefixIcon: const Icon(Icons.phone),
                suffixIcon: ContactPickerButton(
                  onPicked: (n) {
                    _phoneController.text = n;
                    _searchClients(n);
                  },
                ),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Numéro requis' : null,
              onChanged: _searchClients,
            ),

            // Suggestions (Agence uniquement — D18)
            if (isAgence && _suggestions.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withAlpha(20),
                        blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Column(
                  children: _suggestions.map((client) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.person, size: 20),
                    title: Text(client.fullName),
                    subtitle: Text(client.phoneNumber),
                    onTap: () => _selectClient(client),
                  )).toList(),
                ),
              ),

            // Client sélectionné (Agence uniquement — D18)
            if (isAgence && _selectedClient != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.withdrawColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.withdrawColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      '${_selectedClient!.fullName} - ${_selectedClient!.phoneNumber}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    )),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() {
                        _selectedClient = null;
                        _phoneController.clear();
                      }),
                    ),
                  ],
                ),
              ),
            ],

            // Nouveau client (Agence uniquement — D18)
            if (isAgence && _isNewClient) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.accentColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accentColor.withAlpha(50)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [
                      Icon(Icons.person_add, color: AppColors.accentColor, size: 20),
                      SizedBox(width: 8),
                      Text('Nouveau client',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(labelText: 'Prénom *'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(labelText: 'Nom *'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _cnibController,
                      decoration: const InputDecoration(labelText: 'N° CNIB'),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Montant
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                labelText: 'Montant (FCFA) *',
                hintText: '5000',
                prefixIcon: Icon(Icons.attach_money, color: headerColor),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Montant requis';
                final a = double.tryParse(v.replaceAll(RegExp(r'[^\d]'), ''));
                if (a == null || a <= 0) return 'Montant invalide';
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),

            // Aperçu commission
            if (_selectedType != null && _amountValue != null)
              Builder(builder: (context) {
                final c = CommissionCalculator.compute(
                    amount: _amountValue!, commissionTaux: _selectedType!.commissionTaux);
                if (c <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('Commission: ${_currencyFormat.format(c)}',
                      style: TextStyle(fontSize: 13,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500)),
                );
              }),

            const SizedBox(height: 32),

            // Le `+` ne fait plus que lancer un USSD (D18) — la transaction
            // est créée par le SMS entrant. Bouton visible seulement si le
            // type sélectionné a un code USSD (sinon l'encart d'info plus
            // haut explique pourquoi c'est impossible).
            if (_selectedType?.ussdCode != null &&
                _selectedType!.ussdCode!.isNotEmpty)
              ElevatedButton.icon(
                onPressed: _launchUssd,
                icon: const Icon(Icons.phone_forwarded),
                label: Text(
                  'Lancer ${_selectedType!.label} (USSD)',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: headerColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
