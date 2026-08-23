import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/licence/licence_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../services/patron_api.dart';

/// Vue "patron" multi-agence : demandes d'affiliation reçues (à approuver
/// en assignant une de ses agences) + liste des agences avec leur état de
/// synchronisation. Réservé aux comptes Agence.
class MesAgencesScreen extends StatefulWidget {
  const MesAgencesScreen({super.key});

  @override
  State<MesAgencesScreen> createState() => _MesAgencesScreenState();
}

class _MesAgencesScreenState extends State<MesAgencesScreen> {
  String? _telephone;
  List<Map<String, dynamic>> _demandes = [];
  List<Map<String, dynamic>> _agences = [];
  List<Map<String, dynamic>> _mesAgencesOwned = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final telephone = await LicenceStorage.getTelephone();
    if (telephone == null) {
      setState(() => _loading = false);
      return;
    }
    final results = await Future.wait([
      PatronApi.demandesEnAttente(telephone),
      PatronApi.mesAgencesSync(telephone),
      PatronApi.mesAgencesOwned(telephone),
    ]);
    if (!mounted) return;
    setState(() {
      _telephone = telephone;
      _demandes = results[0];
      _agences = results[1];
      _mesAgencesOwned = results[2];
      _loading = false;
    });
  }

  Future<void> _approuver(Map<String, dynamic> demande) async {
    final agenceId = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Assigner une agence à ${demande['demandeur_telephone']}'),
        children: _mesAgencesOwned.isEmpty
            ? [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Aucune agence disponible. Créez-en une depuis les paramètres.'),
                ),
              ]
            : _mesAgencesOwned
                .map((a) => SimpleDialogOption(
                      onPressed: () => Navigator.pop(ctx, a['id'] as int),
                      child: Text(a['nom'] as String),
                    ))
                .toList(),
      ),
    );
    if (agenceId == null || _telephone == null) return;

    final erreur = await PatronApi.approuver(
      telephone: _telephone!,
      demandeId: demande['id'] as int,
      agenceId: agenceId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(erreur ?? 'Demande approuvée')),
    );
    if (erreur == null) _load();
  }

  Future<void> _rejeter(Map<String, dynamic> demande) async {
    if (_telephone == null) return;
    final erreur = await PatronApi.rejeter(telephone: _telephone!, demandeId: demande['id'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(erreur ?? 'Demande rejetée')),
    );
    if (erreur == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes agences')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_demandes.isNotEmpty) ...[
                    const Text('Demandes en attente',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ..._demandes.map((d) => Card(
                          child: ListTile(
                            title: Text(d['demandeur_telephone'] as String),
                            subtitle: const Text('Souhaite opérer une de vos agences'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.check_circle, color: AppColors.withdrawColor),
                                  onPressed: () => _approuver(d),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.cancel, color: Colors.red),
                                  onPressed: () => _rejeter(d),
                                ),
                              ],
                            ),
                          ),
                        )),
                    const SizedBox(height: 24),
                  ],
                  const Text('Vos agences',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_agences.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Aucune donnée synchronisée pour le moment.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._agences.map((a) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.store_outlined, color: AppColors.primaryColor),
                            title: Text(a['nom'] as String),
                            subtitle: Text('${a['tx_count']} transaction(s) synchronisée(s)'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push('/agences/mes-agences/${a['id']}'),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
