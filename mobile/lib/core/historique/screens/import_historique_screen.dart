import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../licence/licence_storage.dart';
import '../../theme/app_colors.dart';
import '../historique_service.dart';
import '../historique_storage.dart';

class ImportHistoriqueScreen extends StatefulWidget {
  const ImportHistoriqueScreen({super.key});

  @override
  State<ImportHistoriqueScreen> createState() => _ImportHistoriqueScreenState();
}

/// La période (donc le prix, D5) doit être choisie AVANT toute demande
/// d'achat — le coût dépend de `date_debut`, contrairement à l'ancien flux
/// qui achetait un forfait fixe puis choisissait la période après coup.
enum _ScreenState { periode, attente, importing, done }

class _ImportHistoriqueScreenState extends State<ImportHistoriqueScreen> {
  _ScreenState _state = _ScreenState.periode;
  String? _message;
  bool _isError = false;
  bool _loading = false;
  bool _dejaActif = false;

  // Période
  DateTime _dateDebut = DateTime.now().subtract(const Duration(days: 90));
  DateTime _dateFin = DateTime.now();
  int _montantEnAttente = 0;

  // Import progress
  int _traites = 0;
  int _total = 0;
  ResultatImport? _resultat;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final active = await HistoriqueStorage.estActive();
    if (mounted) setState(() => _dejaActif = active);
  }

  /// Bouton principal de l'étape "période" : si déjà activé sur cet
  /// appareil (n'importe quel achat précédent), on importe directement —
  /// sinon on envoie la demande pour CETTE période précise, dont le prix
  /// est calculé par le backend (D5).
  Future<void> _continuer() async {
    if (_dejaActif) {
      await _startImport();
      return;
    }

    final tel = await LicenceStorage.getTelephone();
    if (tel == null) {
      _setMsg('Configurez d\'abord votre licence', error: true);
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });
    final result = await HistoriqueImportService.demanderAchat(tel, _dateDebut);
    setState(() => _loading = false);

    if (result.dejaActive) {
      setState(() => _dejaActif = true);
      await _startImport();
      return;
    }

    if (result.succes || result.message.contains('attente') || result.montant > 0) {
      setState(() {
        _state = _ScreenState.attente;
        _montantEnAttente = result.montant;
        _message = result.message;
        _isError = false;
      });
      _startPolling(tel);
    } else {
      _setMsg(result.message, error: true);
    }
  }

  void _startPolling(String telephone) {
    HistoriqueImportService.attendreValidation(telephone).listen((statut) async {
      if (!mounted) return;
      if (statut == StatutAchat.active) {
        setState(() => _dejaActif = true);
        await _startImport();
      } else if (statut == StatutAchat.timeout) {
        setState(() {
          _state = _ScreenState.periode;
          _message = 'Délai dépassé — réessayez ou contactez le support.';
          _isError = true;
        });
      }
    });
  }

  Future<void> _selectDate(bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _dateDebut : _dateFin,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) {
      setState(() {
        if (isStart) {
          _dateDebut = date;
        } else {
          _dateFin = date;
        }
      });
    }
  }

  void _setShortcut(int days) {
    setState(() {
      _dateDebut = DateTime.now().subtract(Duration(days: days));
      _dateFin = DateTime.now();
    });
  }

  Future<void> _startImport() async {
    // Vérifier et demander la permission READ_SMS
    var status = await Permission.sms.status;
    if (!status.isGranted) {
      status = await Permission.sms.request();
      if (!status.isGranted) {
        _setMsg('Permission SMS refusée. Activez-la dans les paramètres.', error: true);
        return;
      }
    }

    setState(() {
      _state = _ScreenState.importing;
      _traites = 0;
      _total = 0;
    });

    final result = await HistoriqueImportService.importerSMS(
      dateDebut: _dateDebut,
      dateFin: _dateFin,
      onProgress: (t, total) {
        if (mounted) setState(() { _traites = t; _total = total; });
      },
    );

    if (mounted) {
      setState(() {
        _resultat = result;
        _state = _ScreenState.done;
      });
    }
  }

  void _setMsg(String msg, {bool error = false}) {
    if (mounted) setState(() { _message = msg; _isError = error; });
  }

  final _dateFmt = DateFormat('dd/MM/yyyy');
  final _fcfaFmt = NumberFormat.decimalPattern('fr_FR');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Historique SMS')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_message != null)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: _isError ? Colors.red.shade50 : Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_message!,
                style: TextStyle(
                  color: _isError ? Colors.red.shade700 : Colors.green.shade700,
                  fontSize: 13,
                )),
          ),
        if (_state == _ScreenState.periode) _buildPeriode(),
        if (_state == _ScreenState.attente) _buildAttente(),
        if (_state == _ScreenState.importing) _buildImporting(),
        if (_state == _ScreenState.done) _buildDone(),
      ],
    );
  }

  // ── Étape 1 : Période (détermine le prix, D5) ─────────────
  Widget _buildPeriode() {
    final montantEstime = HistoriqueImportService.estimerCout(_dateDebut);
    return Column(
      children: [
        Icon(Icons.date_range, size: 56, color: AppColors.primaryColor),
        const SizedBox(height: 12),
        Text(
          _dejaActif ? 'Choisissez la période à importer' : 'Depuis quand voulez-vous importer ?',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (!_dejaActif)
          Text(
            'Gratuit jusqu\'à 1 an en arrière. Au-delà, 200 FCFA par année supplémentaire.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 13),
          ),
        const SizedBox(height: 24),

        _buildDateField('Du', _dateDebut, () => _selectDate(true)),
        const SizedBox(height: 12),
        _buildDateField('Au', _dateFin, () => _selectDate(false)),

        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: [
            _buildChip('3 mois', 90),
            _buildChip('6 mois', 180),
            _buildChip('1 an', 365),
            _buildChip('2 ans', 730),
          ],
        ),

        if (!_dejaActif) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: montantEstime == 0 ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: montantEstime == 0 ? Colors.green.shade200 : Colors.orange.shade200,
              ),
            ),
            child: Row(
              children: [
                Text('Coût estimé :',
                    style: TextStyle(
                      color: montantEstime == 0 ? Colors.green.shade800 : Colors.orange.shade800,
                    )),
                const Spacer(),
                Text(
                  montantEstime == 0 ? 'Gratuit' : '${_fcfaFmt.format(montantEstime)} FCFA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: montantEstime == 0 ? Colors.green.shade800 : Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _loading ? null : _continuer,
          icon: Icon(_dejaActif ? Icons.search : Icons.check_circle_outline),
          label: Text(
            _loading
                ? 'Patientez...'
                : _dejaActif
                    ? 'Analyser et importer'
                    : (montantEstime == 0 ? 'Activer gratuitement' : 'Continuer'),
            style: const TextStyle(fontSize: 16),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ],
    );
  }

  // ── Étape 2 : En attente de paiement ──────────────────────
  Widget _buildAttente() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const CircularProgressIndicator(),
        const SizedBox(height: 24),
        Text('En attente de validation...',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text('${_fcfaFmt.format(_montantEnAttente)} FCFA',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      color: Colors.orange.shade800)),
              const SizedBox(height: 4),
              Text('à envoyer via Orange Money',
                  style: TextStyle(color: Colors.orange.shade700, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Cette page se met à jour automatiquement dès validation.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500]),
        ),
      ],
    );
  }

  Widget _buildDateField(String label, DateTime date, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Text(label, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(width: 12),
            Text(_dateFmt.format(date),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const Spacer(),
            Icon(Icons.calendar_today, size: 20, color: Colors.grey[500]),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, int days) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      onPressed: () => _setShortcut(days),
    );
  }

  // ── Étape 3 : Import en cours ──────────────────────────────
  Widget _buildImporting() {
    final progress = _total > 0 ? _traites / _total : 0.0;
    return Column(
      children: [
        const SizedBox(height: 40),
        Icon(Icons.sync, size: 48, color: AppColors.primaryColor),
        const SizedBox(height: 16),
        Text('Import en cours...',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 12,
            backgroundColor: Colors.grey[200],
          ),
        ),
        const SizedBox(height: 8),
        Text('$_traites / $_total SMS',
            style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        const SizedBox(height: 24),
        Text('Ne fermez pas l\'application.',
            style: TextStyle(
                color: Colors.orange.shade700,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  // ── Étape 4 : Résultat ─────────────────────────────────────
  Widget _buildDone() {
    final r = _resultat!;
    return Column(
      children: [
        const SizedBox(height: 20),
        Icon(
          r.succes ? Icons.check_circle : Icons.error,
          size: 64,
          color: r.succes ? AppColors.depositColor : Colors.red,
        ),
        const SizedBox(height: 16),
        Text(
          r.succes ? 'Import terminé !' : 'Erreur',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: r.succes ? AppColors.depositColor : Colors.red,
              ),
        ),
        const SizedBox(height: 24),
        if (r.succes) ...[
          _buildStatRow('SMS analysés', '${r.total}'),
          _buildStatRow('Transactions créées', '${r.crees}'),
          _buildStatRow('SMS ignorés', '${r.ignores}'),
          const SizedBox(height: 8),
          Text('(non reconnus ou déjà importés)',
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ] else
          Text(r.message, style: const TextStyle(color: Colors.red)),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () => context.go('/transactions'),
          icon: const Icon(Icons.list),
          label: const Text('Voir les transactions'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => setState(() => _state = _ScreenState.periode),
          icon: const Icon(Icons.replay),
          label: const Text('Importer une autre période'),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$label : ', style: TextStyle(color: Colors.grey[600])),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ],
      ),
    );
  }
}
