import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/database/transaction_repository.dart';
import '../../../core/licence/licence_guard.dart';
import '../../../core/theme/app_colors.dart';
import '../../clients/models/client_model.dart';
import '../../clients/providers/client_provider.dart';
import '../../dashboard/providers/dashboard_provider.dart';
import '../providers/transaction_provider.dart';

/// Écran de confirmation / édition / revalidation d'une transaction
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

  Map<String, dynamic>? _txData;
  ClientModel? _selectedClient;
  bool _isLoading = true;
  List<ClientModel> _suggestions = [];
  Timer? _debounce;

  final _currencyFormat = NumberFormat.currency(
      locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  String get _status => _txData?['status'] as String? ?? 'pending';
  bool get _isPending => _status == 'pending';
  bool get _isCompleted => _status == 'completed';
  bool get _isCancelled => _status == 'cancelled' || _status == 'rejected';

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    final db = await DatabaseHelper.instance.database;
    final rows = await db.rawQuery('''
      SELECT t.*, o.name as operator_name
      FROM transactions t
      LEFT JOIN operators o ON t.operator_id = o.id
      WHERE t.id = ?
    ''', [widget.transactionId]);

    if (rows.isNotEmpty && mounted) {
      final tx = rows.first;
      setState(() {
        _txData = tx;
        _phoneController.text = (tx['client_phone'] as String?) ?? '';
        _nameController.text = (tx['client_name'] as String?) ?? '';
        _cnibController.text = (tx['client_cnib'] as String?) ?? '';
        _birthDateController.text = (tx['client_birth_date'] as String?) ?? '';
        _isLoading = false;
      });
      // Chercher un client existant par téléphone
      final phone = (tx['client_phone'] as String?) ?? '';
      if (phone.isNotEmpty) _searchClient(phone);
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
        if (results.length == 1 && _selectedClient == null) {
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

  Map<String, dynamic> _buildUpdates() {
    return {
      'client_id': _selectedClient?.id,
      'client_name': _nameController.text.trim().isEmpty
          ? null
          : _nameController.text.trim(),
      'client_cnib': _cnibController.text.trim().isEmpty
          ? null
          : _cnibController.text.trim(),
      'client_birth_date': _birthDateController.text.trim().isEmpty
          ? null
          : _birthDateController.text.trim(),
      'client_phone': _phoneController.text.trim(),
    };
  }

  void _refreshProviders() {
    ref.read(transactionsProvider.notifier).loadTransactions();
    ref.read(pendingTransactionsProvider.notifier).loadPending();
    ref.invalidate(dashboardStatsProvider(null));
  }

  /// Confirmer une transaction pending
  Future<void> _confirmTransaction() async {
    if (_txData == null) return;
    final autorise = await LicenceGuard.verifier(
        context, ActionType.confirmerTransaction);
    if (!autorise || !mounted) return;
    if (!_formKey.currentState!.validate()) return;

    final updates = _buildUpdates();

    // Si nouveau client (pas sélectionné dans la liste), le créer
    if (_selectedClient == null && _phoneController.text.trim().isNotEmpty) {
      await _createNewClient(updates);
    }

    await TransactionRepository.instance.confirm(
        widget.transactionId, updates);
    _refreshProviders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction confirmée'),
          backgroundColor: AppColors.depositColor,
        ),
      );
      context.pop();
    }
  }

  /// Annuler une transaction (pending → cancelled OU completed → cancelled)
  Future<void> _cancelTransaction() async {
    if (_txData == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler la transaction ?'),
        content: Text(
          _isPending
              ? 'Cette transaction sera annulée et déplacée dans la liste des transactions annulées.'
              : 'Cette transaction confirmée sera annulée. Vous pourrez la revalider plus tard.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Retour'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.withdrawColor),
            child: const Text('Annuler la transaction'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    if (_isCompleted) {
      await TransactionRepository.instance.cancel(widget.transactionId);
    } else {
      await TransactionRepository.instance.reject(widget.transactionId);
    }
    _refreshProviders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction annulée'),
          backgroundColor: AppColors.withdrawColor,
        ),
      );
      context.pop();
    }
  }

  /// Revalider une transaction annulée (cancelled → completed)
  Future<void> _revalidateTransaction() async {
    if (_txData == null) return;
    final autorise = await LicenceGuard.verifier(
        context, ActionType.confirmerTransaction);
    if (!autorise || !mounted) return;
    if (!_formKey.currentState!.validate()) return;

    final updates = _buildUpdates();

    if (_selectedClient == null && _phoneController.text.trim().isNotEmpty) {
      await _createNewClient(updates);
    }

    await TransactionRepository.instance
        .revalidate(widget.transactionId, updates: updates);
    _refreshProviders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction revalidée'),
          backgroundColor: AppColors.depositColor,
        ),
      );
      context.pop();
    }
  }

  /// Sauvegarder les modifications (client info) d'une transaction confirmée
  Future<void> _saveEdits() async {
    if (_txData == null) return;
    if (!_formKey.currentState!.validate()) return;

    final updates = _buildUpdates();

    if (_selectedClient == null && _phoneController.text.trim().isNotEmpty) {
      await _createNewClient(updates);
    }

    await TransactionRepository.instance
        .update(updates, widget.transactionId);
    _refreshProviders();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informations mises à jour'),
          backgroundColor: AppColors.primaryColor,
        ),
      );
      context.pop();
    }
  }

  /// Crée un nouveau client et met à jour le updates map
  Future<void> _createNewClient(Map<String, dynamic> updates) async {
    final name = _nameController.text.trim();
    String firstName = '';
    String lastName = '';
    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      firstName = parts.first;
      lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    final newClient = ClientModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      firstName: firstName.isNotEmpty ? firstName : 'Client',
      lastName: lastName.isNotEmpty ? lastName : _phoneController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      cnibNumber: _cnibController.text.trim().isEmpty
          ? null
          : _cnibController.text.trim(),
      birthDate: _birthDateController.text.trim().isEmpty
          ? null
          : _birthDateController.text.trim(),
      operatorId: _txData?['operator_id'] as String?,
    );
    final savedClient = await ref.read(clientsProvider.notifier).addClient(newClient);
    updates['client_id'] = savedClient.id;
    updates['client_name'] = savedClient.fullName;
    setState(() => _selectedClient = savedClient);
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

    if (_txData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transaction')),
        body: const Center(child: Text('Transaction introuvable')),
      );
    }

    final tx = _txData!;
    final isDeposit = tx['transaction_type'] == 'deposit';
    final color = isDeposit ? AppColors.depositColor : AppColors.withdrawColor;
    final amount = (tx['amount'] as num?)?.toDouble() ?? 0;
    final commission = (tx['commission'] as num?)?.toDouble() ?? 0;

    String title;
    if (_isPending) {
      title = 'Confirmer la transaction';
    } else if (_isCancelled) {
      title = 'Transaction annulée';
    } else {
      title = 'Détails transaction';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: _isCancelled ? Colors.grey[700] : color,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Statut badge
            if (_isCancelled)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Cette transaction a été annulée. Vous pouvez la revalider.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),

            // Résumé transaction (non modifiable)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (_isCancelled ? Colors.grey : color).withAlpha(15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: (_isCancelled ? Colors.grey : color).withAlpha(60)),
              ),
              child: Column(
                children: [
                  Icon(
                    isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 40,
                    color: _isCancelled ? Colors.grey : color,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isDeposit ? 'DÉPÔT' : 'RETRAIT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isCancelled ? Colors.grey : color,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currencyFormat.format(amount),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _isCancelled ? Colors.grey[700] : color,
                      fontSize: 28,
                    ),
                  ),
                  if (commission > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Commission: ${_currencyFormat.format(commission)}',
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    (tx['operator_name'] as String?) ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  if (tx['operator_transaction_id'] != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Réf: ${tx['operator_transaction_id']}',
                      style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontFamily: 'monospace'),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(
                        DateTime.parse(tx['created_at'] as String)),
                    style: TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // SMS brut
            if (tx['sms_raw'] != null)
              ExpansionTile(
                leading: const Icon(Icons.sms, size: 20),
                title: const Text('SMS original',
                    style: TextStyle(fontSize: 14)),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      tx['sms_raw'] as String,
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),

            // Infos porteur
            Text(
              _isPending
                  ? 'Informations du porteur'
                  : 'Modifier les informations du porteur',
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

            // Téléphone
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

            // Suggestions
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

            // === BOUTONS ===
            if (_isPending) ...[
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
                onPressed: _cancelTransaction,
                icon: const Icon(Icons.close),
                label: const Text('Annuler'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.withdrawColor,
                  side: const BorderSide(color: AppColors.withdrawColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ] else if (_isCompleted) ...[
              ElevatedButton.icon(
                onPressed: _saveEdits,
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer les modifications',
                    style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _cancelTransaction,
                icon: const Icon(Icons.cancel_outlined),
                label: const Text('Annuler cette transaction'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.withdrawColor,
                  side: const BorderSide(color: AppColors.withdrawColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ] else if (_isCancelled) ...[
              ElevatedButton.icon(
                onPressed: _revalidateTransaction,
                icon: const Icon(Icons.restore),
                label: const Text('Revalider la transaction',
                    style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.depositColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
