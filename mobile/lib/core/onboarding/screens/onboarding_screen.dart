import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../licence/licence_service.dart';
import '../../theme/app_colors.dart';
import '../affiliation_service.dart';
import '../catalog_sync_service.dart';
import '../models/catalog_models.dart';
import '../onboarding_state.dart';

/// Premier lancement : type de compte -> téléphone/pays -> agence (avec
/// essai gratuit) -> sélection des opérateurs du catalogue à importer.
/// Inséré avant /setup-pin dans le router (le catalogue doit exister avant
/// que l'agent puisse créer sa première transaction).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _catalogService = CatalogSyncService();

  int _step = 0;
  String _accountType = 'agence';
  final _telephoneController = TextEditingController();
  List<CatalogCountry> _countries = [];
  String? _countryCode;
  final _agenceNomController =
      TextEditingController(text: 'Agence principale');
  // 'creer' = premier appareil sur ce compte ; 'rejoindre' = rattacher cet
  // appareil à un compte existant (patron multi-agence OU second téléphone
  // d'un même Particulier — mécanisme identique, copie différente, D7).
  String _setupMode = 'creer';
  final _linkTelephoneController = TextEditingController();
  List<CatalogOperator> _operators = [];
  final Set<int> _selectedOperatorIds = {};
  String? _localAgenceId;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _telephoneController.dispose();
    _agenceNomController.dispose();
    _linkTelephoneController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final countries = await _catalogService.fetchCountries();
      if (!mounted) return;
      setState(() {
        _countries = countries;
        if (countries.isNotEmpty) _countryCode = countries.first.code;
      });
    } catch (_) {
      // Pas bloquant — l'agent pourra réessayer, le champ pays restera vide.
    }
  }

  Future<void> _createAgenceAndTrial() async {
    if (_telephoneController.text.trim().isEmpty) {
      setState(() => _error = 'Entrez votre numéro de téléphone');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final resultat = await LicenceService.demarrerEssaiAvecAgence(
      telephone: _telephoneController.text.trim(),
      accountType: _accountType,
      agenceNom: _agenceNomController.text.trim(),
    );

    if (!resultat.reussi) {
      setState(() {
        _loading = false;
        _error = resultat.message;
      });
      return;
    }

    final localAgenceId = await _catalogService.createLocalAgence(
      nom: _agenceNomController.text.trim(),
      backendAgenceId: resultat.agenceBackendId!,
      isDefault: true,
    );
    await ref.read(onboardingStatusServiceProvider).saveAccountType(_accountType);
    ref.invalidate(accountTypeProvider);
    if (_countryCode != null) {
      await ref.read(onboardingStatusServiceProvider).saveCountryCode(_countryCode!);
    }

    if (_countryCode != null) {
      try {
        final ops = await _catalogService.fetchOperators(
          _countryCode!,
          accountType: _accountType,
        );
        if (mounted) setState(() => _operators = ops);
      } catch (_) {
        // L'agent pourra configurer manuellement depuis les paramètres.
      }
    }

    if (!mounted) return;
    setState(() {
      _localAgenceId = localAgenceId;
      _loading = false;
      _step = 3;
    });
  }

  /// Rattachement à un compte existant (D-affiliation) au lieu de créer un
  /// nouvel espace — même mécanisme pour les deux profils, deux usages
  /// différents : un agent qui rejoint une agence de son patron, ou un
  /// Particulier qui relie son second téléphone à son compte principal
  /// (D7 : jamais de vocabulaire "agence" côté Particulier, mais sous le
  /// capot c'est la même AffiliationRequest/Agence cachée).
  Future<void> _rejoindreCompte() async {
    if (_telephoneController.text.trim().isEmpty) {
      setState(() => _error = 'Entrez votre numéro de téléphone');
      return;
    }
    if (_linkTelephoneController.text.trim().isEmpty) {
      setState(() => _error = _accountType == 'particulier'
          ? 'Entrez le numéro de votre autre téléphone'
          : 'Entrez le numéro de votre patron');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final resultat = await AffiliationService.demander(
      demandeurTelephone: _telephoneController.text.trim(),
      patronTelephone: _linkTelephoneController.text.trim(),
    );

    if (!resultat.reussi) {
      setState(() {
        _loading = false;
        _error = resultat.message;
      });
      return;
    }

    await ref.read(onboardingStatusServiceProvider).saveAccountType(_accountType);
    ref.invalidate(accountTypeProvider);
    if (_countryCode != null) {
      await ref.read(onboardingStatusServiceProvider).saveCountryCode(_countryCode!);
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _step = 4;
    });
    _pollApprobation();
  }

  void _pollApprobation() {
    AffiliationService.attendreApprobation().listen((poll) async {
      if (!mounted) return;
      if (poll.statut == 'approuve') {
        final ok = await AffiliationService.recupererLicencePourAgence(
          telephone: _telephoneController.text.trim(),
          agenceId: poll.agenceId!,
        );
        if (!mounted) return;
        if (!ok) {
          setState(() => _error = 'Licence introuvable pour cette agence - réessayez.');
          return;
        }
        final localAgenceId = await _catalogService.createLocalAgence(
          nom: poll.agenceNom!,
          backendAgenceId: poll.agenceId!,
          isDefault: true,
        );
        if (_countryCode != null) {
          try {
            final ops = await _catalogService.fetchOperators(
              _countryCode!,
              accountType: _accountType,
            );
            if (mounted) setState(() => _operators = ops);
          } catch (_) {}
        }
        if (!mounted) return;
        setState(() {
          _localAgenceId = localAgenceId;
          _step = 3;
        });
      } else if (poll.statut == 'rejete') {
        setState(() {
          _error = _accountType == 'particulier'
              ? 'Votre demande a été refusée depuis votre autre téléphone.'
              : 'Votre demande d\'affiliation a été refusée par le patron.';
          _step = 2;
        });
      } else if (poll.statut == 'timeout') {
        setState(() {
          _error = 'Délai d\'attente dépassé - réessayez.';
          _step = 2;
        });
      }
    });
  }

  Future<void> _finishImport() async {
    if (_localAgenceId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final selected = _operators
          .where((o) => _selectedOperatorIds.contains(o.id))
          .toList();
      if (selected.isNotEmpty) {
        await _catalogService.importOperators(selected, _localAgenceId!);
      }
      await ref.read(onboardingStatusServiceProvider).markComplete();
      ref.invalidate(isOnboardingCompleteProvider);
      if (mounted) context.go('/setup-pin');
    } catch (e) {
      setState(() => _error = "Erreur lors de l'import : $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            if (_error != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!,
                    style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
              ),
            Expanded(
              child: IndexedStack(
                index: _step,
                children: [
                  _buildAccountTypeStep(),
                  _buildPhoneCountryStep(),
                  _buildAgenceStep(),
                  _buildOperatorsStep(),
                  _buildWaitingApprovalStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Un compte Particulier n'a pas besoin de nommer une agence (D7) — le
  /// libellé de l'étape 3 reste générique ("Configuration"), jamais
  /// "Agence", mais les deux profils traversent les mêmes étapes.
  List<String> get _stepLabels => _accountType == 'particulier'
      ? const ['Compte', 'Téléphone', 'Configuration', 'Opérateurs']
      : const ['Compte', 'Téléphone', 'Agence', 'Opérateurs'];

  int get _displayStep => _step;

  Widget _buildHeader() {
    final labels = _stepLabels;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i <= _displayStep;
          return Expanded(
            child: Column(
              children: [
                Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: active ? AppColors.primaryColor : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active ? AppColors.primaryColor : Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAccountTypeStep() {
    return _StepScaffold(
      title: 'Particulier ou agence ?',
      subtitle:
          'Un compte "Agence" gère commissions et clients. Un compte "Particulier" suit simplement ses propres opérations, sans commission.',
      child: Column(
        children: [
          _AccountTypeCard(
            label: 'Agence',
            description: 'Usage professionnel, avec commissions et clients',
            selected: _accountType == 'agence',
            onTap: () => setState(() => _accountType = 'agence'),
          ),
          const SizedBox(height: 12),
          _AccountTypeCard(
            label: 'Particulier',
            description: 'Suivi personnel multi-opérateur, sans commission',
            selected: _accountType == 'particulier',
            onTap: () => setState(() => _accountType = 'particulier'),
          ),
        ],
      ),
      onNext: () => setState(() => _step = 1),
    );
  }

  Widget _buildPhoneCountryStep() {
    return _StepScaffold(
      title: 'Votre numéro et votre pays',
      subtitle:
          'Ça détermine les opérateurs mobile money qu\'on va vous proposer.',
      onBack: () => setState(() => _step = 0),
      onNext: _loading ? null : () => setState(() => _step = 2),
      nextLabel: _loading ? 'Création...' : 'Continuer',
      child: Column(
        children: [
          TextField(
            controller: _telephoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Numéro de téléphone',
              hintText: '70123456',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          if (_countries.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            )
          else
            DropdownButtonFormField<String>(
              initialValue: _countryCode,
              decoration: const InputDecoration(
                labelText: 'Pays',
                border: OutlineInputBorder(),
              ),
              items: _countries
                  .map((c) => DropdownMenuItem(
                        value: c.code,
                        child: Text('${c.name} (${c.dialCode})'),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _countryCode = v),
            ),
        ],
      ),
    );
  }

  Widget _buildAgenceStep() {
    return _accountType == 'particulier' ? _buildParticulierSetupStep() : _buildAgenceSetupStep();
  }

  /// Compte Agence : créer une nouvelle agence (nommée), ou rejoindre une
  /// agence existante d'un patron via son numéro (D-affiliation).
  Widget _buildAgenceSetupStep() {
    final rejoindre = _setupMode == 'rejoindre';
    return _StepScaffold(
      title: rejoindre ? 'Rejoindre une agence existante' : 'Nommez votre agence',
      subtitle: rejoindre
          ? 'Entrez le numéro de votre patron - il devra approuver votre demande et vous assigner une agence.'
          : 'Vous pourrez en ajouter d\'autres plus tard. Chaque agence démarre avec un essai gratuit.',
      onBack: () => setState(() => _step = 1),
      onNext: _loading ? null : (rejoindre ? _rejoindreCompte : _createAgenceAndTrial),
      nextLabel: _loading
          ? (rejoindre ? 'Envoi...' : 'Création...')
          : (rejoindre ? 'Envoyer la demande' : 'Créer et continuer'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'creer', label: Text('Créer')),
              ButtonSegment(value: 'rejoindre', label: Text('Rejoindre')),
            ],
            selected: {_setupMode},
            onSelectionChanged: (v) => setState(() => _setupMode = v.first),
          ),
          const SizedBox(height: 16),
          if (rejoindre)
            TextField(
              controller: _linkTelephoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro de téléphone du patron',
                hintText: '70123456',
                border: OutlineInputBorder(),
              ),
            )
          else
            TextField(
              controller: _agenceNomController,
              decoration: const InputDecoration(
                labelText: 'Nom de l\'agence',
                border: OutlineInputBorder(),
              ),
            ),
        ],
      ),
    );
  }

  /// Compte Particulier : aucun vocabulaire "agence" — juste "premier
  /// téléphone" (cas par défaut, un tap) ou "relier à un compte existant"
  /// pour quelqu'un qui a déjà MoneyTracking sur un autre téléphone (même
  /// mécanisme D-affiliation, copie différente, D7).
  Widget _buildParticulierSetupStep() {
    final relier = _setupMode == 'rejoindre';
    return _StepScaffold(
      title: relier ? 'Relier à votre compte existant' : 'Configuration de votre suivi',
      subtitle: relier
          ? 'Entrez le numéro de votre autre téléphone MoneyTracking - vous devrez approuver la demande depuis cet appareil.'
          : 'Si vous utilisez déjà MoneyTracking sur un autre téléphone, vous pouvez relier celui-ci au lieu d\'en repartir de zéro.',
      onBack: () => setState(() => _step = 1),
      onNext: _loading
          ? null
          : (relier
              ? _rejoindreCompte
              : () {
                  _agenceNomController.text = 'Mon suivi personnel';
                  _createAgenceAndTrial();
                }),
      nextLabel: _loading
          ? (relier ? 'Envoi...' : 'Création...')
          : (relier ? 'Envoyer la demande' : 'Continuer'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'creer', label: Text('Premier téléphone')),
              ButtonSegment(value: 'rejoindre', label: Text('J\'ai déjà un compte')),
            ],
            selected: {_setupMode},
            onSelectionChanged: (v) => setState(() => _setupMode = v.first),
          ),
          if (relier) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _linkTelephoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Numéro de votre autre téléphone',
                hintText: '70123456',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildWaitingApprovalStep() {
    return _StepScaffold(
      title: 'En attente d\'approbation',
      subtitle:
          'Votre demande a été envoyée à ${_linkTelephoneController.text.trim()}. '
          'Cet écran se mettra à jour automatiquement dès qu\'il aura répondu.',
      onBack: () => setState(() => _step = 2),
      child: const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildOperatorsStep() {
    return _StepScaffold(
      title: 'Choisissez vos opérateurs',
      subtitle: 'Sélectionnez ceux que vous utilisez - modifiable plus tard.',
      onNext: _loading ? null : _finishImport,
      nextLabel: _loading ? 'Import...' : 'Terminer',
      child: _operators.isEmpty
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Aucun opérateur disponible pour ce pays pour le moment. '
                'Vous pourrez en configurer manuellement depuis les paramètres.',
              ),
            )
          : Column(
              children: _operators.map((op) {
                final selected = _selectedOperatorIds.contains(op.id);
                return CheckboxListTile(
                  value: selected,
                  title: Text(op.name),
                  subtitle: Text('${op.transactionTypes.length} type(s) de transaction'),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _selectedOperatorIds.add(op.id);
                    } else {
                      _selectedOperatorIds.remove(op.id);
                    }
                  }),
                );
              }).toList(),
            ),
    );
  }
}

class _StepScaffold extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final String nextLabel;

  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onBack,
    this.onNext,
    this.nextLabel = 'Continuer',
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 24),
          child,
          const SizedBox(height: 32),
          Row(
            children: [
              if (onBack != null)
                Expanded(
                  child: OutlinedButton(
                    onPressed: onBack,
                    child: const Text('Retour'),
                  ),
                ),
              if (onBack != null) const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: onNext,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(nextLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountTypeCard extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _AccountTypeCard({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryColor.withValues(alpha: 0.08) : Colors.white,
          border: Border.all(
            color: selected ? AppColors.primaryColor : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColors.primaryColor : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(description,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
