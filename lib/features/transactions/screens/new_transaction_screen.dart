import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ussd/ussd_launcher.dart';
import '../../caisse/providers/caisse_provider.dart';
import '../../clients/models/client_model.dart';
import '../../clients/providers/client_provider.dart';
import '../../operators/models/operator_model.dart';
import '../../operators/providers/operator_provider.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

/// Écran de nouvelle transaction
/// Deux modes : "Lancer USSD" (la transaction sera créée par le SMS)
///              "Création manuelle" (si pas de SMS)
class NewTransactionScreen extends ConsumerStatefulWidget {
  final String transactionType;

  const NewTransactionScreen({super.key, required this.transactionType});

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
  ClientModel? _selectedClient;
  bool _isNewClient = false;
  List<ClientModel> _suggestions = [];
  Timer? _debounce;
  final _currencyFormat =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  bool get isDeposit => widget.transactionType == 'deposit';

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

  /// Lance le USSD — PAS de création de transaction ici
  /// C'est le SMS entrant qui va créer la transaction automatiquement
  Future<void> _launchUssd() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOperator == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un opérateur')),
      );
      return;
    }

    final template = isDeposit
        ? _selectedOperator!.ussdDepositTemplate
        : _selectedOperator!.ussdWithdrawTemplate;

    if (template == null || template.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pas de template USSD configuré pour cet opérateur')),
      );
      return;
    }

    final phone = _phoneController.text.trim();
    final amount = double.tryParse(
        _amountController.text.replaceAll(RegExp(r'[^\d]'), ''));
    if (amount == null || amount <= 0) return;

    // Créer le client si nouveau (avant le USSD)
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
    }

    // Lancer le USSD — PAS de transaction créée ici
    final launched = await UssdLauncher.launch(
      template: template,
      numero: phone,
      montant: amount,
    );

    if (mounted) {
      if (launched) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'USSD lancé — ${_currencyFormat.format(amount)}. '
              'La transaction sera créée automatiquement à la réception du SMS.',
            ),
            backgroundColor: AppColors.primaryColor,
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Échec du lancement USSD'),
            backgroundColor: Colors.red,
          ),
        );
      }
      context.pop();
    }
  }

  /// Création manuelle — uniquement si pas de SMS
  Future<void> _createManual() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOperator == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un opérateur')),
      );
      return;
    }

    final amount = double.tryParse(
        _amountController.text.replaceAll(RegExp(r'[^\d]'), ''));
    if (amount == null || amount <= 0) return;

    final phone = _phoneController.text.trim();
    final commission = _selectedOperator!.calculateCommission(
        amount, widget.transactionType);

    String? clientId = _selectedClient?.id;
    String? clientName = _selectedClient?.fullName;

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
      clientId = newClient.id;
      clientName = newClient.fullName;
    }

    final transaction = TransactionModel(
      id: const Uuid().v4(),
      operatorId: _selectedOperator!.id,
      clientId: clientId,
      transactionType: widget.transactionType,
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
      transactionType: widget.transactionType,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${isDeposit ? 'Dépôt' : 'Retrait'} de ${_currencyFormat.format(amount)} créé manuellement',
          ),
          backgroundColor:
              isDeposit ? AppColors.depositColor : AppColors.withdrawColor,
        ),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final operatorsAsync = ref.watch(operatorsProvider);
    final hasUssdTemplate = _selectedOperator != null &&
        ((isDeposit
                ? _selectedOperator!.ussdDepositTemplate
                : _selectedOperator!.ussdWithdrawTemplate) ??
            '')
            .isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(isDeposit ? 'Nouveau dépôt' : 'Nouveau retrait'),
        backgroundColor:
            isDeposit ? AppColors.depositColor : AppColors.withdrawColor,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Sélection opérateur
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
                      onSelected: (v) =>
                          setState(() => _selectedOperator = v ? op : null),
                      selectedColor: AppColors.primaryColor.withAlpha(50),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),

            // Numéro client
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Numéro du client *',
                hintText: '70 12 34 56',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Numéro requis' : null,
              onChanged: _searchClients,
            ),

            // Suggestions
            if (_suggestions.isNotEmpty)
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

            // Client sélectionné
            if (_selectedClient != null) ...[
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
                      '${_selectedClient!.fullName} — ${_selectedClient!.phoneNumber}',
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

            // Nouveau client
            if (_isNewClient) ...[
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
                prefixIcon: Icon(Icons.attach_money,
                    color: isDeposit ? AppColors.depositColor : AppColors.withdrawColor),
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Montant requis';
                final a = double.tryParse(v.replaceAll(RegExp(r'[^\d]'), ''));
                if (a == null || a <= 0) return 'Montant invalide';
                return null;
              },
            ),

            // Aperçu commission
            if (_selectedOperator != null && _amountController.text.isNotEmpty)
              Builder(builder: (context) {
                final a = double.tryParse(
                    _amountController.text.replaceAll(RegExp(r'[^\d]'), ''));
                if (a == null || a <= 0) return const SizedBox.shrink();
                final c = _selectedOperator!.calculateCommission(a, widget.transactionType);
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

            // === DEUX BOUTONS : USSD ou Manuel ===
            if (hasUssdTemplate)
              ElevatedButton.icon(
                onPressed: _launchUssd,
                icon: const Icon(Icons.phone_forwarded),
                label: Text(
                  isDeposit ? 'Lancer le dépôt (USSD)' : 'Lancer le retrait (USSD)',
                  style: const TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDeposit ? AppColors.depositColor : AppColors.withdrawColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),

            if (hasUssdTemplate) const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _createManual,
              icon: const Icon(Icons.edit_note),
              label: const Text('Créer manuellement (sans SMS)'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
