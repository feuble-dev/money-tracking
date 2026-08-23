import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/licence/licence_storage.dart';
import '../../../core/theme/app_colors.dart';
import '../services/patron_api.dart';

/// Équivalent "Mes agences" pour un compte Particulier, sans aucun
/// vocabulaire d'agence (D7) — un Particulier a souvent deux téléphones
/// (deux lignes/opérateurs différents) et veut voir tout au même endroit.
/// Sous le capot c'est exactement le même mécanisme D-affiliation qu'un
/// patron multi-agence, mais avec une seule agence cachée par compte : pas
/// de sélecteur d'agence à l'approbation, juste "autoriser ce téléphone".
class MesTelephonesScreen extends StatefulWidget {
  const MesTelephonesScreen({super.key});

  @override
  State<MesTelephonesScreen> createState() => _MesTelephonesScreenState();
}

class _MesTelephonesScreenState extends State<MesTelephonesScreen> {
  String? _telephone;
  List<Map<String, dynamic>> _demandes = [];
  List<Map<String, dynamic>> _telephonesLies = [];
  int? _monEspaceId;
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
    final owned = results[2];
    setState(() {
      _telephone = telephone;
      _demandes = results[0];
      _telephonesLies = results[1];
      _monEspaceId = owned.isNotEmpty ? owned.first['id'] as int : null;
      _loading = false;
    });
  }

  Future<void> _approuver(Map<String, dynamic> demande) async {
    if (_telephone == null) return;
    if (_monEspaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun espace personnel trouvé — réessayez plus tard')),
      );
      return;
    }
    final erreur = await PatronApi.approuver(
      telephone: _telephone!,
      demandeId: demande['id'] as int,
      agenceId: _monEspaceId!,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(erreur ?? 'Téléphone autorisé')),
    );
    if (erreur == null) _load();
  }

  Future<void> _rejeter(Map<String, dynamic> demande) async {
    if (_telephone == null) return;
    final erreur = await PatronApi.rejeter(telephone: _telephone!, demandeId: demande['id'] as int);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(erreur ?? 'Demande refusée')),
    );
    if (erreur == null) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes téléphones')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Si vous utilisez MoneyTracking sur un autre téléphone, reliez-le ici pour '
                    'retrouver toutes vos opérations au même endroit.',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  if (_demandes.isNotEmpty) ...[
                    const Text('Demandes en attente',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ..._demandes.map((d) => Card(
                          child: ListTile(
                            title: Text(d['demandeur_telephone'] as String),
                            subtitle: const Text('Souhaite être relié à ce compte'),
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
                  const Text('Téléphones reliés',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_telephonesLies.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'Aucun autre téléphone relié pour le moment.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  else
                    ..._telephonesLies.map((a) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.phone_android, color: AppColors.primaryColor),
                            title: const Text('Téléphone lié'),
                            subtitle: Text('${a['tx_count']} transaction(s) synchronisée(s)'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => context.push(
                              '/agences/mes-agences/${a['id']}?title=${Uri.encodeComponent('Téléphone lié')}',
                            ),
                          ),
                        )),
                ],
              ),
            ),
    );
  }
}
