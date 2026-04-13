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

enum _ScreenState { loading, achat, attente, periode, importing, done }

class _ImportHistoriqueScreenState extends State<ImportHistoriqueScreen> {
  _ScreenState _state = _ScreenState.loading;
  String? _message;
  bool _isError = false;

  // Période
  DateTime _dateDebut = DateTime.now().subtract(const Duration(days: 90));
  DateTime _dateFin = DateTime.now();

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
    if (mounted) {
      setState(() {
        _state = active ? _ScreenState.periode : _ScreenState.achat;
      });
    }
  }

  Future<void> _acheter() async {
    final tel = await LicenceStorage.getTelephone();
    if (tel == null) {
      _setMsg('Configurez d\'abord votre licence', error: true);
      return;
    }

    setState(() => _state = _ScreenState.loading);
    final result = await HistoriqueImportService.demanderAchat(tel);

    if (result.dejaActive) {
      setState(() => _state = _ScreenState.periode);
      return;
    }

    if (result.succes || result.message.contains('attente')) {
      setState(() => _state = _ScreenState.attente);
      _startPolling(tel);
    } else {
      setState(() => _state = _ScreenState.achat);
      _setMsg(result.message, error: true);
    }
  }

  void _startPolling(String telephone) {
    HistoriqueImportService.attendreValidation(telephone).listen((statut) {
      if (!mounted) return;
      if (statut == StatutAchat.active) {
        setState(() => _state = _ScreenState.periode);
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
    if (_state == _ScreenState.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

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
        if (_state == _ScreenState.achat) _buildAchat(),
        if (_state == _ScreenState.attente) _buildAttente(),
        if (_state == _ScreenState.periode) _buildPeriode(),
        if (_state == _ScreenState.importing) _buildImporting(),
        if (_state == _ScreenState.done) _buildDone(),
      ],
    );
  }

  // ── Écran 1: Achat ────────────────────────────────────────
  Widget _buildAchat() {
    return Column(
      children: [
        Icon(Icons.history, size: 64, color: AppColors.primaryColor),
        const SizedBox(height: 16),
        Text('Import Historique SMS',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                )),
        const SizedBox(height: 8),
        Text(
          'Récupérez toutes vos anciennes transactions depuis vos SMS.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 24),
        ...[
          'Illimité sur cet appareil',
          'Choisissez la période à importer',
          'Tous les opérateurs configurés',
        ].map((t) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.depositColor, size: 20),
                  const SizedBox(width: 10),
                  Text(t, style: const TextStyle(fontSize: 14)),
                ],
              ),
            )),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Text('Prix:', style: TextStyle(color: Colors.orange.shade800)),
              const Spacer(),
              Text('2 000 FCFA',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.orange.shade800,
                  )),
              Text(' (unique)',
                  style: TextStyle(
                      color: Colors.orange.shade600, fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _acheter,
          icon: const Icon(Icons.shopping_cart),
          label: const Text('Acheter — 2 000 FCFA',
              style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Envoyez 2 000 FCFA via Orange Money\net attendez la validation.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
      ],
    );
  }

  // ── Écran 2: En attente ───────────────────────────────────
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
        const SizedBox(height: 12),
        Icon(Icons.check_circle, color: Colors.green.shade400, size: 24),
        const SizedBox(height: 8),
        Text('Demande envoyée',
            style: TextStyle(color: Colors.green.shade600)),
        const SizedBox(height: 16),
        Text(
          'Nous vérifions votre paiement.\nCette page se met à jour automatiquement.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500]),
        ),
      ],
    );
  }

  // ── Écran 3: Choix période ────────────────────────────────
  Widget _buildPeriode() {
    return Column(
      children: [
        Icon(Icons.date_range, size: 48, color: AppColors.primaryColor),
        const SizedBox(height: 16),
        Text('Période à importer',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                )),
        const SizedBox(height: 24),

        // Date debut
        _buildDateField('Du', _dateDebut, () => _selectDate(true)),
        const SizedBox(height: 12),
        _buildDateField('Au', _dateFin, () => _selectDate(false)),

        const SizedBox(height: 16),
        // Raccourcis
        Wrap(
          spacing: 8,
          children: [
            _buildChip('Ce mois', 30),
            _buildChip('3 mois', 90),
            _buildChip('6 mois', 180),
            _buildChip('1 an', 365),
          ],
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: _startImport,
          icon: const Icon(Icons.search),
          label: const Text('Analyser et importer',
              style: TextStyle(fontSize: 16)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
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

  // ── Écran 4: Import en cours ──────────────────────────────
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

  // ── Écran 5: Résultat ─────────────────────────────────────
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
