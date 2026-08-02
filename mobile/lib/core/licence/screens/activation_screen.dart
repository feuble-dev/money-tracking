import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../licence_service.dart';
import '../licence_storage.dart';
import '../../theme/app_colors.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  final _telephoneCtrl = TextEditingController();
  final _cleCtrl = TextEditingController();
  bool _loading = false;
  String? _message;
  bool _isError = false;
  int _selectedDuree = 1;

  @override
  void initState() {
    super.initState();
    _chargerTelephone();
  }

  Future<void> _chargerTelephone() async {
    final tel = await LicenceStorage.getTelephone();
    if (tel != null && mounted) {
      _telephoneCtrl.text = tel;
    }
  }

  @override
  void dispose() {
    _telephoneCtrl.dispose();
    _cleCtrl.dispose();
    super.dispose();
  }

  void _setMessage(String msg, {bool error = false}) {
    if (mounted) {
      setState(() {
        _message = msg;
        _isError = error;
      });
    }
  }

  // ── Essai gratuit ──────────────────────────────────────────
  Future<void> _demarrerEssai() async {
    final tel = _telephoneCtrl.text.trim();
    if (tel.isEmpty) {
      _setMessage('Entrez votre numéro de téléphone', error: true);
      return;
    }
    setState(() => _loading = true);

    final result = await LicenceService.demarrerEssai(tel);

    setState(() => _loading = false);

    if (result.reussi) {
      _setMessage(result.message);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) context.go('/dashboard');
    } else {
      _setMessage(result.message, error: true);
    }
  }

  // ── Récupérer licence en ligne ─────────────────────────────
  Future<void> _recupererLicence() async {
    final tel = _telephoneCtrl.text.trim();
    if (tel.isEmpty) {
      _setMessage('Entrez votre numéro de téléphone', error: true);
      return;
    }
    setState(() => _loading = true);

    final ok = await LicenceService.recupererLicence(tel);

    setState(() => _loading = false);

    if (ok) {
      _setMessage('Licence récupérée avec succès !');
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) context.go('/dashboard');
    } else {
      _setMessage(
        'Aucune licence active trouvée pour ce numéro.',
        error: true,
      );
    }
  }

  // ── Demander activation (paiement) ─────────────────────────
  Future<void> _demanderActivation() async {
    final tel = _telephoneCtrl.text.trim();
    if (tel.isEmpty) {
      _setMessage('Entrez votre numéro de téléphone', error: true);
      return;
    }
    setState(() => _loading = true);

    final result = await LicenceService.demanderActivation(
      telephone: tel,
      dureeMois: _selectedDuree,
    );

    setState(() => _loading = false);

    if (result.reussi) {
      _setMessage(result.message);
    } else {
      _setMessage(result.message, error: true);
    }
  }

  // ── Activer avec clé manuelle ──────────────────────────────
  Future<void> _activerAvecCle() async {
    final cle = _cleCtrl.text.trim();
    final tel = _telephoneCtrl.text.trim();
    if (cle.isEmpty) {
      _setMessage('Entrez votre clé de licence', error: true);
      return;
    }
    if (tel.isEmpty) {
      _setMessage('Entrez votre numéro de téléphone', error: true);
      return;
    }
    setState(() => _loading = true);

    final result = await LicenceService.activerAvecCle(cle, tel);

    setState(() => _loading = false);

    if (result.reussi) {
      _setMessage(result.message);
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) context.go('/dashboard');
    } else {
      _setMessage(result.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Activer MoneyTracking'),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/logo.png',
                width: 80,
                height: 80,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'MoneyTracking',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryColor,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Activez votre licence',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),

            // Message
            if (_message != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: _isError
                      ? Colors.red.shade50
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isError
                        ? Colors.red.shade200
                        : Colors.green.shade200,
                  ),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color: _isError
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                    fontSize: 13,
                  ),
                ),
              ),

            // ── Section 1 : Récupération automatique ──────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.cell_tower,
                            color: AppColors.primaryColor, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Récupération automatique',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _telephoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Numéro de téléphone',
                        hintText: '70123456',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _recupererLicence,
                            icon: const Icon(Icons.search, size: 18),
                            label: const Text(
                              'Récupérer',
                              style: TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _loading ? null : _demarrerEssai,
                            icon: const Icon(Icons.card_giftcard, size: 18),
                            label: const Text(
                              'Essai gratuit',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ── Section Souscrire ──────────────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_cart,
                            color: Colors.orange.shade700, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Souscrire un abonnement',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Tarifs
                    _buildTarifChip(1, '1 000 FCFA / mois'),
                    _buildTarifChip(12, '10 000 FCFA / an (-17%)'),
                    _buildTarifChip(24, '18 000 FCFA / 2 ans (-25%)'),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _loading ? null : _demanderActivation,
                        icon: const Icon(Icons.send, size: 18),
                        label: const Text('Envoyer la demande'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Divider
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('ou',
                      style: TextStyle(color: Colors.grey[500])),
                ),
                const Expanded(child: Divider()),
              ],
            ),

            const SizedBox(height: 8),

            // ── Section 2 : Clé manuelle ──────────────────────
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.vpn_key,
                            color: Colors.grey[700], size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Clé manuelle (sans internet)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cleCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'Clé de licence',
                        hintText: 'MT-XXXXXXXX-XXXXXXXXYYYYMMDD',
                        prefixIcon: Icon(Icons.key),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _activerAvecCle,
                        icon: const Icon(Icons.lock_open, size: 18),
                        label: const Text('Activer avec cette clé'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Loading
            if (_loading) const Center(child: CircularProgressIndicator()),

            const SizedBox(height: 16),

            // Contact
            Text(
              'Pas de licence ? Contactez MoneyTracking',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTarifChip(int mois, String label) {
    final selected = _selectedDuree == mois;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => setState(() => _selectedDuree = mois),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected
                  ? Colors.orange.shade700
                  : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: selected
                ? Colors.orange.shade50
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected
                    ? Colors.orange.shade700
                    : Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
