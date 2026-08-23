import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/licence/licence_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../services/patron_api.dart';

/// Détail complet en lecture seule d'une agence affiliée/possédée (droits
/// patron confirmés : "détail complet", "lecture seule" — jamais d'action
/// d'écriture depuis cet écran).
class AgenceSyncDetailScreen extends StatefulWidget {
  final int agenceId;
  /// Titre affiché à la place du nom d'agence backend (ex: pour un compte
  /// Particulier, où ce nom est un espace caché "Mon suivi personnel" qui
  /// n'a pas vocation à être montré tel quel — D7).
  final String? title;
  const AgenceSyncDetailScreen({super.key, required this.agenceId, this.title});

  @override
  State<AgenceSyncDetailScreen> createState() => _AgenceSyncDetailScreenState();
}

class _AgenceSyncDetailScreenState extends State<AgenceSyncDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _data;
  bool _loading = true;
  late final TabController _tabController;
  final _fcfa = NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final telephone = await LicenceStorage.getTelephone();
    if (telephone != null) {
      final data = await PatronApi.agenceDetail(telephone, widget.agenceId);
      if (mounted) setState(() => _data = data);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final agenceNom = widget.title ?? (_data?['agence'] as Map?)?['nom'] as String? ?? 'Agence';
    final transactions = List<Map<String, dynamic>>.from(_data?['transactions'] as List? ?? []);
    final clients = List<Map<String, dynamic>>.from(_data?['clients'] as List? ?? []);
    final caisseOps = List<Map<String, dynamic>>.from(_data?['caisse_operations'] as List? ?? []);

    return Scaffold(
      appBar: AppBar(
        title: Text(agenceNom),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Transactions (${transactions.length})'),
            Tab(text: 'Clients (${clients.length})'),
            Tab(text: 'Caisse (${caisseOps.length})'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('Impossible de charger cette agence'))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTransactionsList(transactions),
                    _buildClientsList(clients),
                    _buildCaisseList(caisseOps),
                  ],
                ),
    );
  }

  Widget _buildTransactionsList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const Center(child: Text('Aucune transaction'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final t = items[i];
        final isIn = t['direction'] == 'in';
        return Card(
          child: ListTile(
            leading: Icon(
              isIn ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIn ? AppColors.depositColor : AppColors.withdrawColor,
            ),
            title: Text('${t['transaction_type_label']} — ${t['operator_name']}'),
            subtitle: Text('${t['client_name'] ?? ''} ${t['client_phone'] ?? ''}\n${t['created_at']}'),
            isThreeLine: true,
            trailing: Text(
              _fcfa.format(num.tryParse(t['amount'].toString()) ?? 0),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClientsList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const Center(child: Text('Aucun client'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final c = items[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline, color: AppColors.primaryColor),
            title: Text('${c['first_name']} ${c['last_name']}'),
            subtitle: Text(c['phone_number'] as String? ?? ''),
          ),
        );
      },
    );
  }

  Widget _buildCaisseList(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const Center(child: Text('Aucune opération caisse'));
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final o = items[i];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.accentColor),
            title: Text('${o['type']} — ${o['operator_name']}'),
            subtitle: Text('${o['note'] ?? ''}\n${o['created_at']}'),
            isThreeLine: true,
            trailing: Text(_fcfa.format(num.tryParse(o['montant'].toString()) ?? 0)),
          ),
        );
      },
    );
  }
}
