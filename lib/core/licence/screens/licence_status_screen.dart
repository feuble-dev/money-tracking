import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../licence_storage.dart';
import '../licence_service.dart';
import '../../theme/app_colors.dart';

class LicenceStatusScreen extends StatefulWidget {
  const LicenceStatusScreen({super.key});

  @override
  State<LicenceStatusScreen> createState() => _LicenceStatusScreenState();
}

class _LicenceStatusScreenState extends State<LicenceStatusScreen> {
  LicenceStatut? _statut;
  int _jours = 0;
  String? _dateFin;
  String? _code;
  String? _telephone;
  bool _loading = true;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final statut = await LicenceStorage.verifierLocalement();
    final jours = await LicenceStorage.getJoursRestants();
    final dateFin = await LicenceStorage.getDateFin();
    final code = await LicenceStorage.getCode();
    final tel = await LicenceStorage.getTelephone();

    if (mounted) {
      setState(() {
        _statut = statut;
        _jours = jours;
        _dateFin = dateFin;
        _code = code;
        _telephone = tel;
        _loading = false;
      });
    }
  }

  Future<void> _verifierEnLigne() async {
    setState(() => _syncing = true);
    final tel = _telephone;
    if (tel != null) {
      await LicenceService.recupererLicence(tel);
    }
    await _charger();
    setState(() => _syncing = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vérification terminée')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ma Licence')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Ma Licence')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Statut card
            _buildStatutCard(),
            const SizedBox(height: 16),

            // Détails
            if (_statut != LicenceStatut.nonActivee) ...[
              _buildDetailCard(),
              const SizedBox(height: 16),
            ],

            // Bannière expiration
            if (_statut == LicenceStatut.expireBientot)
              _buildExpirationBanner(),

            if (_statut == LicenceStatut.expiree)
              _buildExpiredBanner(),

            const SizedBox(height: 16),

            // Actions
            if (_statut != LicenceStatut.nonActivee)
              OutlinedButton.icon(
                onPressed: _syncing ? null : _verifierEnLigne,
                icon: _syncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                label: const Text('Vérifier en ligne'),
              ),

            const SizedBox(height: 8),

            if (_statut == LicenceStatut.expiree ||
                _statut == LicenceStatut.expireBientot ||
                _statut == LicenceStatut.nonActivee)
              ElevatedButton.icon(
                onPressed: () => context.push('/activation'),
                icon: const Icon(Icons.add_circle_outline),
                label: Text(
                  _statut == LicenceStatut.nonActivee
                      ? 'Activer ma licence'
                      : 'Renouveler ma licence',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatutCard() {
    IconData icon;
    Color color;
    String label;

    switch (_statut!) {
      case LicenceStatut.active:
        icon = Icons.check_circle;
        color = Colors.green;
        label = 'Licence Active';
      case LicenceStatut.essaiActif:
        icon = Icons.card_giftcard;
        color = Colors.blue;
        label = 'Essai Gratuit';
      case LicenceStatut.expireBientot:
        icon = Icons.warning;
        color = Colors.orange;
        label = 'Expire bientôt';
      case LicenceStatut.expiree:
        icon = Icons.cancel;
        color = Colors.red;
        label = 'Licence Expirée';
      case LicenceStatut.nonActivee:
        icon = Icons.lock;
        color = Colors.grey;
        label = 'Aucune Licence';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 56, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            if (_jours > 0 && _statut != LicenceStatut.nonActivee)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '$_jours jours restants',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_dateFin != null)
              _buildDetailRow(
                'Expire le',
                _dateFin!.substring(0, 10),
              ),
            if (_telephone != null)
              _buildDetailRow('Téléphone', _telephone!),
            if (_code != null)
              _buildDetailRow('Code', _code!),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 13,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpirationBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.orange.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Votre licence expire dans $_jours jours.\n'
              'Renouvelez maintenant pour ne pas perdre vos données.',
              style: TextStyle(
                color: Colors.orange.shade800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpiredBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error, color: Colors.red.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Votre licence a expiré.\n'
              'Renouvelez pour continuer à créer des transactions.',
              style: TextStyle(
                color: Colors.red.shade800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
