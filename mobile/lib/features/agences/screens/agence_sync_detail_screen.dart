import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/licence/licence_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/amount_text.dart';
import '../../../core/format/formats.dart';
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

  /// Les dates arrivent du serveur en ISO brut (« 2026-10-27T14:03:22 ») —
  /// affichées au format habituel de l'app.
  static String _date(Object? v) {
    final d = DateTime.tryParse('${v ?? ''}');
    return d == null ? '${v ?? ''}' : AppFormats.dateTime.format(d);
  }

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
    final resume = _data?['resume'] as Map?;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: items.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(children: [
            if (resume != null) _Resume(resume: resume, fcfa: _fcfa, date: _date),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Text('Aucune transaction synchronisée pour le moment'),
              ),
          ]);
        }
        final t = items[index - 1];
        final isIn = t['direction'] == 'in';
        final cancelled = t['status'] == 'cancelled' || t['status'] == 'rejected';
        return Card(
          child: ListTile(
            leading: Icon(
              isIn ? Icons.arrow_downward : Icons.arrow_upward,
              color: cancelled
                  ? Colors.grey
                  : isIn ? AppColors.depositColor : AppColors.withdrawColor,
            ),
            title: Text('${t['transaction_type_label']} - ${t['operator_name']}',
                style: TextStyle(decoration: cancelled ? TextDecoration.lineThrough : null)),
            subtitle: Text('${t['client_name'] ?? ''} ${t['client_phone'] ?? ''}\n'
                '${_date(t['created_at'])}${cancelled ? ' · annulée' : t['status'] == 'pending' ? ' · à vérifier' : ''}'),
            isThreeLine: true,
            trailing: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.32),
              child: AmountText(
                _fcfa.format(num.tryParse(t['amount'].toString()) ?? 0),
                alignment: AlignmentDirectional.centerEnd,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: cancelled ? Colors.grey : null,
                  decoration: cancelled ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
          ),
        );
      },
      ),
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
            title: Text('${o['type']} - ${o['operator_name']}'),
            subtitle: Text('${o['note'] ?? ''}\n${_date(o['created_at'])}'),
            isThreeLine: true,
            trailing: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.32),
              child: AmountText(
                _fcfa.format(num.tryParse(o['montant'].toString()) ?? 0),
                alignment: AlignmentDirectional.centerEnd,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Ce que l'agence a fait aujourd'hui et ce mois-ci (annulées exclues).
class _Resume extends StatelessWidget {
  final Map resume;
  final NumberFormat fcfa;
  final String Function(Object?) date;
  const _Resume({required this.resume, required this.fcfa, required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bloc(String title, Map? b) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.bodySmall),
                const SizedBox(height: 4),
                AmountText(fcfa.format(b?['commissions'] ?? 0),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 2),
                Text('${b?['operations'] ?? 0} op. · ${fcfa.format(b?['volume'] ?? 0)}',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        );
    final last = resume['derniere_synchro'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            bloc("Commissions aujourd'hui", resume['aujourdhui'] as Map?),
            const SizedBox(width: 10),
            bloc('Commissions du mois', resume['mois'] as Map?),
          ]),
          const SizedBox(height: 8),
          Text(
            last == null ? 'Pas encore de synchronisation' : 'Dernière mise à jour : ${date(last)}',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
