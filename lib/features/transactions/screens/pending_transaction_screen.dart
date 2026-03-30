import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../clients/models/client_model.dart';
import '../../clients/providers/client_provider.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';

/// Écran de confirmation d'une transaction détectée par SMS
class PendingTransactionScreen extends ConsumerStatefulWidget {
  final String transactionId;

  const PendingTransactionScreen({super.key, required this.transactionId});

  @override
  ConsumerState<PendingTransactionScreen> createState() =>
      _PendingTransactionScreenState();
}

class _PendingTransactionScreenState
    extends ConsumerState<PendingTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cnibController = TextEditingController();
  final _birthDateController = TextEditingController();

  TransactionModel? _transaction;
  ClientModel? _selectedClient;
  bool _isLoading = true;
  List<ClientModel> _suggestions = [];
  Timer? _debounce;

  final _currencyFormat = NumberFormat.currency(
      locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    final tx = await ref
        .read(pendingTransactionsProvider.notifier)
        .getById(widget.transactionId);
    if (tx != null && mounted) {
      setState(() {
        _transaction = tx;
        _phoneController.text = tx.clientPhone;
        _nameController.text = tx.clientName ?? '';
        _cnibController.text = tx.clientCnib ?? '';
        _birthDateController.text = tx.clientBirthDate ?? '';
        _isLoading = false;
      });
      // Chercher un client existant
      _searchClient(tx.clientPhone);
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _searchClient(String query) {
    _debounce?.cancel();
    if (query.length < 2) return;
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final results = await ref.read(clientSuggestionsProvider(query).future);
      if (!mounted) return;
      setState(() {
        _suggestions = results;
        if (results.length == 1) {
          _selectClient(results.first);
        }
      });
    });
  }

  void _selectClient(ClientModel client) {
    setState(() {
      _selectedClient = client;
      _nameController.text = client.fullName;
      _cnibController.text = client.cnibNumber ?? '';
      _birthDateController.text = client.birthDate ?? '';
      _suggestions = [];
    });
  }

  Future<void> _selectBirthDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      _birthDateController.text =
          '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    }
  }

  Future<void> _confirmTransaction() async {
    if (_transaction == null) return;
    if (!_formKey.currentState!.validate()) return;

    final updated = _transaction!.copyWith(
      clientId: _selectedClient?.id,
      clientName: _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      clientCnib: _cnibController.text.trim().isEmpty
          ? null
          : _cnibController.text.trim(),
      clientBirthDate: _birthDateController.text.trim().isEmpty
          ? null
          : _birthDateController.text.trim(),
      clientPhone: _phoneController.text.trim(),
      status: 'completed',
    );

    await ref
        .read(pendingTransactionsProvider.notifier)
        .confirmTransaction(updated);
    // Rafraîchir la liste des transactions confirmées
    ref.read(transactionsProvider.notifier).loadTransactions();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Transaction ${_transaction!.isDeposit ? "dépôt" : "retrait"} confirmée',
          ),
          backgroundColor: AppColors.depositColor,
        ),
      );
      context.pop();
    }
  }

  Future<void> _rejectTransaction() async {
    if (_transaction == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter la transaction ?'),
        content: const Text(
            'Cette transaction sera marquée comme rejetée et ne sera pas comptabilisée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.withdrawColor),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(pendingTransactionsProvider.notifier)
          .rejectTransaction(_transaction!.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction rejetée'),
            backgroundColor: AppColors.withdrawColor,
          ),
        );
        context.pop();
      }
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nameController.dispose();
    _phoneController.dispose();
    _cnibController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_transaction == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction')),
        body: const Center(child: Text('Transaction introuvable')),
      );
    }

    final tx = _transaction!;
    final isDeposit = tx.isDeposit;
    final color = isDeposit ? AppColors.depositColor : AppColors.withdrawColor;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirmer la transaction'),
        backgroundColor: color,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: 'Rejeter',
            onPressed: _rejectTransaction,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Résumé de la transaction détectée
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withAlpha(15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withAlpha(60)),
              ),
              child: Column(
                children: [
                  Icon(
                    isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 40,
                    color: color,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDeposit ? 'DÉPÔT DÉTECTÉ' : 'RETRAIT DÉTECTÉ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currencyFormat.format(tx.amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: 28,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx.operatorName ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  if (tx.operatorTransactionId != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Réf: ${tx.operatorTransactionId}',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontFamily: 'monospace'),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // SMS brut (pliable)
            if (tx.smsRaw != null)
              ExpansionTile(
                leading: const Icon(Icons.sms, size: 20),
                title: const Text('SMS original',
                    style: TextStyle(fontSize: 14)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      tx.smsRaw!,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Infos du porteur
            Text(
              'Informations du porteur',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Le même numéro peut être utilisé par différentes personnes. '
              'Renseignez l\'identité du porteur pour cette transaction.',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),

            // Numéro de téléphone
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Numéro du client *',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Numéro requis' : null,
              onChanged: _searchClient,
            ),

            // Suggestions client
            if (_suggestions.isNotEmpty && _selectedClient == null)
              Container(
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: _suggestions.map((client) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(Icons.person, size: 20),
                      title: Text(client.fullName),
                      subtitle: Text(client.phoneNumber),
                      onTap: () => _selectClient(client),
                    );
                  }).toList(),
                ),
              ),

            // Client sélectionné
            if (_selectedClient != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.depositColor.withAlpha(15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        color: AppColors.depositColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Client connu : ${_selectedClient!.fullName}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      onPressed: () => setState(() {
                        _selectedClient = null;
                        _nameController.clear();
                        _cnibController.clear();
                        _birthDateController.clear();
                      }),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Nom complet
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nom complet du porteur',
                prefixIcon: Icon(Icons.person),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // CNIB
            TextFormField(
              controller: _cnibController,
              decoration: const InputDecoration(
                labelText: 'N° pièce d\'identité (CNIB)',
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 16),

            // Date de naissance
            TextFormField(
              controller: _birthDateController,
              decoration: const InputDecoration(
                labelText: 'Date de naissance',
                prefixIcon: Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: _selectBirthDate,
            ),
            const SizedBox(height: 32),

            // Boutons confirmer / rejeter
            ElevatedButton.icon(
              onPressed: _confirmTransaction,
              icon: const Icon(Icons.check),
              label: const Text('Confirmer la transaction',
                  style: TextStyle(fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.depositColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _rejectTransaction,
              icon: const Icon(Icons.close),
              label: const Text('Rejeter'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.withdrawColor,
                side: const BorderSide(color: AppColors.withdrawColor),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
