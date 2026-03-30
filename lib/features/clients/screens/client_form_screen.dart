import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../models/client_model.dart';
import '../providers/client_provider.dart';

/// Écran d'ajout/modification de client
class ClientFormScreen extends ConsumerStatefulWidget {
  final String? clientId;

  const ClientFormScreen({super.key, this.clientId});

  @override
  ConsumerState<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends ConsumerState<ClientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cnibController = TextEditingController();
  final _birthDateController = TextEditingController();
  ClientModel? _existingClient;

  @override
  void initState() {
    super.initState();
    if (widget.clientId != null) {
      _loadClient();
    }
  }

  void _loadClient() {
    final clients = ref.read(clientsProvider);
    clients.whenData((list) {
      final client =
          list.where((c) => c.id == widget.clientId).firstOrNull;
      if (client != null) {
        setState(() {
          _existingClient = client;
          _firstNameController.text = client.firstName;
          _lastNameController.text = client.lastName;
          _phoneController.text = client.phoneNumber;
          _cnibController.text = client.cnibNumber ?? '';
          _birthDateController.text = client.birthDate ?? '';
        });
      }
    });
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    final client = ClientModel(
      id: _existingClient?.id ?? const Uuid().v4(),
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phoneNumber: _phoneController.text.trim(),
      cnibNumber: _cnibController.text.trim().isEmpty
          ? null
          : _cnibController.text.trim(),
      birthDate: _birthDateController.text.trim().isEmpty
          ? null
          : _birthDateController.text.trim(),
      createdAt: _existingClient?.createdAt,
    );

    final notifier = ref.read(clientsProvider.notifier);
    if (_existingClient != null) {
      await notifier.updateClient(client);
    } else {
      await notifier.addClient(client);
    }

    if (mounted) context.pop();
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

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _cnibController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.clientId != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Modifier le client' : 'Nouveau client'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _firstNameController,
              decoration: const InputDecoration(
                labelText: 'Prénom *',
                prefixIcon: Icon(Icons.person),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Prénom requis' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: const InputDecoration(
                labelText: 'Nom *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Nom requis' : null,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Numéro de téléphone *',
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Numéro requis' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cnibController,
              decoration: const InputDecoration(
                labelText: 'N° CNIB',
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 16),
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
            ElevatedButton.icon(
              onPressed: _saveClient,
              icon: const Icon(Icons.save),
              label: Text(isEditing ? 'Modifier' : 'Créer le client'),
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
