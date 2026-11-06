import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../licence/licence_service.dart';
import '../../theme/app_colors.dart';
import '../affiliation_service.dart';
import '../catalog_sync_service.dart';
import '../models/catalog_models.dart';
import '../onboarding_state.dart';

/// Étapes de l'inscription. Le parcours est volontairement court :
/// Bienvenue → Pour qui ? (un geste) → une seule page d'identité →
/// opérateurs. La connexion et le rattachement à un compte existant sont
/// des chemins à part, jamais imposés à un nouvel utilisateur.
enum _Step { welcome, login, profile, identity, operators, waiting }

/// Pour qui est cette installation.
/// - [moi] : compte Particulier (gratuit, D23)
/// - [agence] : compte Agence, l'utilisateur en est le propriétaire
/// - [agent] : rejoindre l'agence d'un patron (D-affiliation)
/// - [relier] : relier ce téléphone à un compte Particulier sans mot de
///   passe (comptes antérieurs à D13) — même mécanisme qu'[agent]
enum _Profile { moi, agence, agent, relier }

/// Premier lancement. Inséré avant /setup-pin dans le router : le catalogue
/// doit exister avant la première transaction.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _catalogService = CatalogSyncService();

  _Step _step = _Step.welcome;
  _Profile _profile = _Profile.moi;

  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _agenceNom = TextEditingController(text: 'Agence principale');
  final _linkPhone = TextEditingController();
  final _loginPhone = TextEditingController();
  final _loginPassword = TextEditingController();

  List<CatalogCountry> _countries = [];
  // Le catalogue ne sert aujourd'hui que le Burkina Faso : valeur par défaut
  // immédiate, sans attendre le réseau (l'ancien écran restait bloqué sur
  // une roue de chargement hors ligne).
  String _countryCode = 'BF';

  List<CatalogOperator> _operators = [];
  final Set<int> _selectedOperatorIds = {};
  String? _localAgenceId;
  List<AgenceLogin>? _loginAgences;
  String? _loginAccountType;
  StreamSubscription<AffiliationStatutPoll>? _pollSub;

  bool _loading = false;
  String? _error;

  String get _accountType =>
      _profile == _Profile.moi || _profile == _Profile.relier ? 'particulier' : 'agence';

  @override
  void initState() {
    super.initState();
    _catalogService.fetchCountries().then((c) {
      if (mounted) setState(() => _countries = c);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _pollSub?.cancel();
    for (final c in [_phone, _password, _agenceNom, _linkPhone, _loginPhone, _loginPassword]) {
      c.dispose();
    }
    super.dispose();
  }

  void _go(_Step step) => setState(() {
        _step = step;
        _error = null;
      });

  void _fail(String message) => setState(() {
        _loading = false;
        _error = message;
      });

  /// Numéro saisi, chiffres seulement (« 70 12 34 56 » → « 70123456 »).
  static String _digits(TextEditingController c) => c.text.replaceAll(RegExp(r'\D'), '');

  static String? _phoneError(String digits) =>
      digits.length < 8 ? 'Entrez un numéro à 8 chiffres' : null;

  // --- Actions -------------------------------------------------------------

  /// Connexion à un compte existant par mot de passe (D13) : instantanée,
  /// sans approbation. Le backend a déjà émis une licence pour cet appareil
  /// sur chaque agence du compte.
  Future<void> _login() async {
    final phone = _digits(_loginPhone);
    if (_phoneError(phone) != null || _loginPassword.text.isEmpty) {
      return _fail('Entrez votre numéro et votre mot de passe');
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await LicenceService.login(telephone: phone, password: _loginPassword.text);
    if (!mounted) return;
    if (!r.reussi) return _fail(r.message);
    final usable = r.agences.where((a) => a.statut == 'active' || a.statut == 'essai').toList();
    if (usable.isEmpty) return _fail('Aucun espace actif sur ce compte.');
    _loginAccountType = r.accountType;
    if (usable.length == 1) {
      await _finishLogin(usable.first);
    } else {
      setState(() {
        _loading = false;
        _loginAgences = usable;
      });
    }
  }

  Future<void> _finishLogin(AgenceLogin agence) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok = await AffiliationService.recupererLicencePourAgence(
      telephone: _digits(_loginPhone),
      agenceId: agence.id,
    );
    if (!mounted) return;
    if (!ok) return _fail('Connexion impossible pour le moment. Réessayez.');
    final accountType = _loginAccountType ?? 'agence';
    _profile = accountType == 'particulier' ? _Profile.moi : _Profile.agence;
    await _saveProfile();
    final localId = await _catalogService.createLocalAgence(
      nom: agence.nom,
      backendAgenceId: agence.id,
      isDefault: true,
    );
    await _toOperators(localId);
  }

  /// Nouveau compte (Particulier ou propriétaire d'agence).
  Future<void> _create() async {
    final phone = _digits(_phone);
    final err = _phoneError(phone) ??
        (_password.text.length < 4 ? 'Choisissez un mot de passe d\'au moins 4 caractères' : null) ??
        (_profile == _Profile.agence && _agenceNom.text.trim().isEmpty
            ? 'Donnez un nom à votre agence'
            : null);
    if (err != null) return _fail(err);
    setState(() {
      _loading = true;
      _error = null;
    });
    // Un Particulier a une agence cachée (D7) : jamais nommée par lui.
    final nom = _profile == _Profile.moi ? 'Mon suivi personnel' : _agenceNom.text.trim();
    final r = await LicenceService.demarrerEssaiAvecAgence(
      telephone: phone,
      accountType: _accountType,
      agenceNom: nom,
      password: _password.text,
    );
    if (!mounted) return;
    if (!r.reussi) return _fail(r.message);
    await _saveProfile();
    final localId = await _catalogService.createLocalAgence(
      nom: nom,
      backendAgenceId: r.agenceBackendId!,
      isDefault: true,
    );
    await _toOperators(localId);
  }

  /// Rejoindre l'agence d'un patron, ou relier un second téléphone à un
  /// ancien compte Particulier : l'autre téléphone doit approuver.
  Future<void> _requestLink() async {
    final phone = _digits(_phone);
    final other = _digits(_linkPhone);
    final err = _phoneError(phone) ??
        (_phoneError(other) == null
            ? null
            : _profile == _Profile.agent
                ? 'Entrez le numéro de votre patron'
                : 'Entrez le numéro de votre autre téléphone');
    if (err != null) return _fail(err);
    setState(() {
      _loading = true;
      _error = null;
    });
    final r = await AffiliationService.demander(demandeurTelephone: phone, patronTelephone: other);
    if (!mounted) return;
    if (!r.reussi) return _fail(r.message);
    await _saveProfile();
    setState(() => _loading = false);
    _go(_Step.waiting);
    _pollSub?.cancel();
    _pollSub = AffiliationService.attendreApprobation().listen(_onPoll);
  }

  Future<void> _onPoll(AffiliationStatutPoll poll) async {
    if (!mounted) return;
    switch (poll.statut) {
      case 'approuve':
        final ok = await AffiliationService.recupererLicencePourAgence(
          telephone: _digits(_phone),
          agenceId: poll.agenceId!,
        );
        if (!mounted) return;
        if (!ok) return _fail('Accès accordé, mais la récupération a échoué. Réessayez.');
        final localId = await _catalogService.createLocalAgence(
          nom: poll.agenceNom!,
          backendAgenceId: poll.agenceId!,
          isDefault: true,
        );
        await _toOperators(localId);
      case 'rejete':
        _go(_Step.identity);
        _fail(_profile == _Profile.agent
            ? 'Votre patron a refusé la demande.'
            : 'La demande a été refusée depuis votre autre téléphone.');
      case 'timeout':
        _go(_Step.identity);
        _fail('Pas de réponse pour le moment. Réessayez plus tard.');
    }
  }

  Future<void> _saveProfile() async {
    final status = ref.read(onboardingStatusServiceProvider);
    await status.saveAccountType(_accountType);
    await status.saveCountryCode(_countryCode);
    ref.invalidate(accountTypeProvider);
  }

  Future<void> _toOperators(String localAgenceId) async {
    List<CatalogOperator> ops = [];
    try {
      ops = await _catalogService.fetchOperators(_countryCode, accountType: _accountType);
    } catch (_) {
      // Hors ligne : on pourra les ajouter plus tard (Paramètres avancés).
    }
    if (!mounted) return;
    setState(() {
      _operators = ops;
      _localAgenceId = localAgenceId;
      _loading = false;
      _step = _Step.operators;
      _error = null;
    });
  }

  Future<void> _finish() async {
    if (_localAgenceId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final selected = _operators.where((o) => _selectedOperatorIds.contains(o.id)).toList();
      if (selected.isNotEmpty) await _catalogService.importOperators(selected, _localAgenceId!);
      await ref.read(onboardingStatusServiceProvider).markComplete();
      ref.invalidate(isOnboardingCompleteProvider);
      if (mounted) context.go('/setup-pin');
    } catch (_) {
      _fail('L\'installation des opérateurs a échoué. Vérifiez votre connexion et réessayez.');
    }
  }

  // --- Écrans --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final page = switch (_step) {
      _Step.welcome => _welcome(),
      _Step.login => _loginPage(),
      _Step.profile => _profilePage(),
      _Step.identity => _identityPage(),
      _Step.operators => _operatorsPage(),
      _Step.waiting => _waitingPage(),
    };
    return PopScope(
      canPop: _step == _Step.welcome,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_loading) _back();
      },
      child: Scaffold(
        backgroundColor: AppColors.lightBackground,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween(begin: const Offset(0.04, 0), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: KeyedSubtree(key: ValueKey(_step), child: page),
          ),
        ),
      ),
    );
  }

  /// Retour : toujours vers l'écran précédent logique.
  void _back() {
    switch (_step) {
      case _Step.login:
        if (_loginAgences != null) {
          setState(() => _loginAgences = null);
        } else {
          _go(_Step.welcome);
        }
      case _Step.profile:
        _go(_Step.welcome);
      case _Step.identity:
        _go(_profile == _Profile.relier ? _Step.login : _Step.profile);
      case _Step.waiting:
        _pollSub?.cancel();
        _go(_Step.identity);
      case _Step.welcome:
      case _Step.operators:
        break;
    }
  }

  Widget _welcome() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Image.asset('assets/logo.png',
                  width: 88,
                  height: 88,
                  errorBuilder: (_, _, _) => const Icon(Icons.account_balance_wallet,
                      size: 88, color: AppColors.primaryColor)),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Votre argent,\nenfin clair.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.15),
          ),
          const SizedBox(height: 12),
          Text(
            'Vos SMS Mobile Money deviennent des opérations rangées, '
            'automatiquement. Rien à saisir.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.4),
          ),
          const Spacer(flex: 2),
          _PrimaryButton(label: 'Commencer', onPressed: () => _go(_Step.profile)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _go(_Step.login),
            child: const Text('J\'ai déjà un compte'),
          ),
        ],
      ),
    );
  }

  Widget _profilePage() {
    void pick(_Profile p) {
      setState(() => _profile = p);
      _go(_Step.identity);
    }

    return _Page(
      onBack: _back,
      title: 'Pour qui ?',
      subtitle: 'Vous pourrez toujours changer d\'avis plus tard.',
      children: [
        _ChoiceCard(
          icon: Icons.person_outline,
          title: 'Pour moi',
          text: 'Suivre mon argent, mes dépenses, mon budget. Gratuit.',
          onTap: () => pick(_Profile.moi),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          icon: Icons.storefront_outlined,
          title: 'Pour mon agence',
          text: 'Je suis agent Mobile Money : commissions, caisse, clients.',
          onTap: () => pick(_Profile.agence),
        ),
        const SizedBox(height: 20),
        Center(
          child: TextButton(
            onPressed: () => pick(_Profile.agent),
            child: const Text('Je travaille dans l\'agence de quelqu\'un'),
          ),
        ),
      ],
    );
  }

  Widget _identityPage() {
    final linking = _profile == _Profile.agent || _profile == _Profile.relier;
    final (title, subtitle) = switch (_profile) {
      _Profile.moi => (
          'Créez votre compte',
          'Votre numéro et un mot de passe : ils vous permettront de retrouver '
              'votre compte sur un autre téléphone.'
        ),
      _Profile.agence => ('Votre agence', 'Chaque nouvelle agence a 3 mois d\'essai offerts.'),
      _Profile.agent => (
          'Rejoindre une agence',
          'Votre patron recevra une demande sur son téléphone et choisira votre agence.'
        ),
      _Profile.relier => (
          'Relier ce téléphone',
          'Confirmez ensuite la demande depuis votre autre téléphone.'
        ),
    };
    return _Page(
      onBack: _back,
      title: title,
      subtitle: subtitle,
      error: _error,
      action: _PrimaryButton(
        label: linking ? 'Envoyer la demande' : 'Continuer',
        loading: _loading,
        onPressed: linking ? _requestLink : _create,
      ),
      children: [
        if (_profile == _Profile.agence) ...[
          _Field(controller: _agenceNom, label: 'Nom de l\'agence', icon: Icons.storefront_outlined),
          const SizedBox(height: 14),
        ],
        _PhoneField(controller: _phone, label: 'Mon numéro'),
        const SizedBox(height: 14),
        if (linking)
          _PhoneField(
            controller: _linkPhone,
            label: _profile == _Profile.agent ? 'Numéro de mon patron' : 'Numéro de mon autre téléphone',
          )
        else
          _PasswordField(controller: _password, label: 'Mot de passe'),
        if (_countries.length > 1) ...[
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _countryCode,
            decoration: _decoration('Pays', Icons.public),
            items: [
              for (final c in _countries)
                DropdownMenuItem(value: c.code, child: Text('${c.name} (${c.dialCode})')),
            ],
            onChanged: (v) => setState(() => _countryCode = v ?? _countryCode),
          ),
        ],
      ],
    );
  }

  Widget _loginPage() {
    if (_loginAgences != null) {
      return _Page(
        onBack: _back,
        title: 'Quelle agence sur ce téléphone ?',
        subtitle: 'Votre compte en a plusieurs : choisissez celle que ce téléphone va gérer.',
        error: _error,
        children: [
          for (final a in _loginAgences!) ...[
            _ChoiceCard(
              icon: Icons.storefront_outlined,
              title: a.nom,
              text: a.statut == 'essai' ? 'En essai gratuit' : 'Active',
              onTap: _loading ? null : () => _finishLogin(a),
            ),
            const SizedBox(height: 12),
          ],
        ],
      );
    }
    return _Page(
      onBack: _back,
      title: 'Bon retour !',
      subtitle: 'Le numéro et le mot de passe de votre compte.',
      error: _error,
      action: _PrimaryButton(label: 'Me connecter', loading: _loading, onPressed: _login),
      children: [
        _PhoneField(controller: _loginPhone, label: 'Mon numéro'),
        const SizedBox(height: 14),
        _PasswordField(
          controller: _loginPassword,
          label: 'Mot de passe',
          onSubmitted: (_) => _login(),
        ),
        const SizedBox(height: 16),
        // Comptes créés avant les mots de passe (D13) : rattachement approuvé
        // depuis l'autre téléphone. Chemin rare, donc discret.
        Center(
          child: TextButton(
            onPressed: () {
              setState(() => _profile = _Profile.relier);
              _go(_Step.identity);
            },
            child: const Text('Mon compte n\'a pas de mot de passe'),
          ),
        ),
      ],
    );
  }

  Widget _operatorsPage() {
    final n = _selectedOperatorIds.length;
    return _Page(
      title: 'Vos opérateurs',
      subtitle: 'Touchez ceux que vous utilisez. Leurs SMS seront reconnus automatiquement.',
      error: _error,
      action: _PrimaryButton(
        label: n == 0 ? 'Plus tard' : 'Terminer',
        loading: _loading,
        onPressed: _finish,
      ),
      children: [
        if (_operators.isEmpty)
          Text(
            'Impossible de charger la liste pour le moment. Vous pourrez ajouter '
            'vos opérateurs ensuite, depuis les Paramètres.',
            style: TextStyle(color: Colors.grey.shade700),
          )
        else
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              for (final op in _operators)
                _OperatorTile(
                  operator: op,
                  selected: _selectedOperatorIds.contains(op.id),
                  onTap: () => setState(() {
                    HapticFeedback.selectionClick();
                    if (!_selectedOperatorIds.remove(op.id)) _selectedOperatorIds.add(op.id);
                  }),
                ),
            ],
          ),
      ],
    );
  }

  Widget _waitingPage() {
    return _Page(
      onBack: _back,
      title: 'Demande envoyée',
      subtitle: 'Dès que ${_digits(_linkPhone)} aura accepté, cet écran continuera tout seul. '
          'Vous pouvez laisser l\'application ouverte.',
      error: _error,
      children: const [
        SizedBox(height: 24),
        Center(child: CircularProgressIndicator()),
      ],
    );
  }
}

// --- Briques visuelles ------------------------------------------------------

InputDecoration _decoration(String label, IconData icon, {Widget? suffix}) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
    );

/// Gabarit d'une étape : retour, titre, texte, contenu, bouton principal en
/// bas (toujours à la même place, à portée du pouce).
class _Page extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? action;
  final VoidCallback? onBack;
  final String? error;

  const _Page({
    required this.title,
    required this.subtitle,
    required this.children,
    this.action,
    this.onBack,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 56,
          child: onBack == null
              ? null
              : Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Retour',
                  ),
                ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(subtitle, style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.4)),
              const SizedBox(height: 28),
              if (error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text(error!, style: TextStyle(color: Colors.red.shade800))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ...children,
            ],
          ),
        ),
        if (action != null)
          Padding(padding: const EdgeInsets.fromLTRB(24, 8, 24, 16), child: action),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const _PrimaryButton({required this.label, this.onPressed, this.loading = false});

  @override
  Widget build(BuildContext context) => FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        child: loading
            ? const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Text(label),
      );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  const _Field({required this.controller, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.next,
        decoration: _decoration(label, icon),
      );
}

class _PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _PhoneField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[\d ]')),
          LengthLimitingTextInputFormatter(14),
        ],
        decoration: _decoration(label, Icons.phone_outlined).copyWith(hintText: '70 12 34 56'),
      );
}

/// Un seul champ avec « afficher », plutôt que deux champs à confirmer.
class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onSubmitted;
  const _PasswordField({required this.controller, required this.label, this.onSubmitted});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => TextField(
        controller: widget.controller,
        obscureText: !_visible,
        onSubmitted: widget.onSubmitted,
        decoration: _decoration(
          widget.label,
          Icons.lock_outline,
          suffix: IconButton(
            tooltip: _visible ? 'Masquer' : 'Afficher',
            icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
            onPressed: () => setState(() => _visible = !_visible),
          ),
        ).copyWith(helperText: 'Au moins 4 caractères'),
      );
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? onTap;

  const _ChoiceCard({required this.icon, required this.title, required this.text, this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withAlpha(22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppColors.primaryColor),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 3),
                      Text(text, style: TextStyle(color: Colors.grey.shade700, height: 1.3)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
      );
}

class _OperatorTile extends StatelessWidget {
  final CatalogOperator operator;
  final bool selected;
  final VoidCallback onTap;

  const _OperatorTile({required this.operator, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = Text(operator.name.isEmpty ? '?' : operator.name[0],
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primaryColor));
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryColor.withAlpha(18) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? AppColors.primaryColor : Colors.grey.shade200,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: operator.logoUrl == null
                          ? Center(child: initial)
                          : Image.network(operator.logoUrl!,
                              fit: BoxFit.cover, errorBuilder: (_, _, _) => Center(child: initial)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(operator.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: AnimatedScale(
                scale: selected ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.check_circle, color: AppColors.primaryColor, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
