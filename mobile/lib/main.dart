import 'dart:async';
import 'package:another_telephony/telephony.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/categories/category_providers.dart';
import 'core/categories/monthly_summary_service.dart';
import 'core/database/database_helper.dart';
import 'core/notifications/notification_service.dart';
import 'core/onboarding/catalog_sync_service.dart';
import 'core/onboarding/onboarding_state.dart';
import 'core/permissions/battery_optimization_helper.dart';
import 'core/permissions/permission_service.dart';
import 'core/router.dart';
import 'core/sms/background_sms_handler.dart';
import 'core/sms/sms_catchup_service.dart';
import 'core/sms/sms_listener.dart';
import 'core/sync/sync_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/caisse/providers/caisse_provider.dart';
import 'features/commissions/screens/commissions_screen.dart';
import 'features/notifications/screens/notifications_screen.dart';
import 'features/transactions/providers/transaction_provider.dart';
import 'features/categories/providers/recurring_provider.dart';
import 'features/dashboard/providers/dashboard_provider.dart';
import 'features/dashboard/providers/particulier_dashboard_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  debugPrint('[MoneyTracking] Démarrage...');

  // Initialiser les locales françaises
  await initializeDateFormatting('fr_FR', null);
  debugPrint('[MoneyTracking] Locales OK');

  // Initialiser la base de données
  try {
    await DatabaseHelper.instance.database;
    debugPrint('[MoneyTracking] Database OK');
  } catch (e) {
    debugPrint('[MoneyTracking] Database ERROR: $e');
  }

  // Initialiser les notifications (non-bloquant)
  try {
    await NotificationService().initialize();
    debugPrint('[MoneyTracking] Notifications OK');
  } catch (e) {
    debugPrint('[MoneyTracking] Notifications ERROR: $e');
  }

  debugPrint('[MoneyTracking] Lancement app...');
  runApp(const ProviderScope(child: MoneyTrackingApp()));
}

/// Application principale MoneyTracking
class MoneyTrackingApp extends ConsumerStatefulWidget {
  const MoneyTrackingApp({super.key});

  @override
  ConsumerState<MoneyTrackingApp> createState() => _MoneyTrackingAppState();
}

class _MoneyTrackingAppState extends ConsumerState<MoneyTrackingApp>
    with WidgetsBindingObserver {
  // ignore: cancel_subscriptions
  dynamic _pollSub;
  // ignore: cancel_subscriptions
  dynamic _syncSub;
  bool _smsListenersRegistered = false;
  bool _permanentlyDeniedDialogShown = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[MoneyTracking] initState');
    WidgetsBinding.instance.addObserver(this);
    _initPermissionsAndSms();
    _initNotificationHandler();
    // Polling toutes les 60s pour notifs générales
    _pollSub = Stream.periodic(const Duration(seconds: 60)).listen((_) {
      ref.invalidate(generalNotificationsProvider);
    });
    // Sync continue et automatique vers le backend (comptes Agence
    // uniquement — SyncService.pushIfNeeded() est un no-op pour un compte
    // Particulier) : visibilité "détail complet" du patron sur ses agences.
    SyncService.pushIfNeeded();
    _resyncCatalog();
    // Récap mensuel des dépenses (compte Particulier) — une fois par mois.
    unawaited(MonthlySummaryService.maybeShow());
    _syncSub = Stream.periodic(const Duration(minutes: 2)).listen((_) {
      SyncService.pushIfNeeded();
      markSmsForegroundAlive();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollSub?.cancel();
    _syncSub?.cancel();
    SmsListenerService().stopListening();
    NotificationService().onNotificationTapped = null;
    super.dispose();
  }

  /// Re-vérifie les permissions SMS à chaque retour au premier plan — pas
  /// seulement au premier lancement. Si l'utilisateur les a accordées entre
  /// temps depuis les réglages système (après un refus initial), on démarre
  /// enfin l'écoute SMS sans attendre un redémarrage complet de l'app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      markSmsForegroundAlive();
      _recheckSmsPermissions();
    }
  }

  Future<void> _recheckSmsPermissions() async {
    if (_smsListenersRegistered) return;
    final granted = await PermissionService.hasSmsPermissions();
    if (granted) {
      await _startSmsListening();
      return;
    }
    if (_permanentlyDeniedDialogShown) return;
    final permanentlyDenied = await PermissionService.isSmsPermanentlyDenied();
    if (permanentlyDenied && mounted) {
      _permanentlyDeniedDialogShown = true;
      final navigatorContext = ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
      if (navigatorContext != null && navigatorContext.mounted) {
        await showDialog<void>(
          context: navigatorContext,
          builder: (ctx) => AlertDialog(
            title: const Text('Permission SMS refusée'),
            content: const Text(
              'MoneyTracking a besoin de lire les SMS pour détecter vos '
              'transactions automatiquement. Cette permission a été refusée '
              'définitivement — vous pouvez l\'accorder depuis les réglages '
              'de l\'application.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Plus tard'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  openAppSettings();
                },
                child: const Text('Ouvrir les réglages'),
              ),
            ],
          ),
        );
      }
    }
  }

  /// Gère le tap sur une notification
  /// Si la transaction a un client → va sur les transactions
  /// Si pas de client → ouvre le formulaire d'ajout client
  void _initNotificationHandler() {
    final notifService = NotificationService();
    notifService.onNotificationTapped = (payload) {
      if (payload == null) return;
      final router = ref.read(routerProvider);
      if (payload.startsWith('cat:')) {
        router.push('/categorize/${payload.substring(4)}');
      } else if (payload.startsWith('tx:')) {
        router.push('/transactions/pending/${payload.substring(3)}');
      } else if (payload == 'summary') {
        router.push('/budget');
      } else {
        router.push('/notifications');
      }
    };
    // Quand une action est effectuée depuis la notif (confirmer/rejeter)
    notifService.onActionPerformed = () {
      ref.read(transactionsProvider.notifier).loadTransactions();
      ref.read(pendingTransactionsProvider.notifier).loadPending();
      ref.invalidate(dashboardStatsProvider(null));
      ref.invalidate(particulierDashboardProvider);
      ref.invalidate(uncategorizedCountProvider);
    };
  }

  /// Met à jour en arrière-plan les patterns SMS des opérateurs déjà
  /// importés (jamais les opérateurs eux-mêmes) — c'est ce qui permet à une
  /// correction du catalogue admin (ex: un pattern mal tagué qui empêchait
  /// des transactions réelles d'être détectées) d'atteindre un appareil
  /// déjà onboardé, sans réinstallation. Silencieux et non-bloquant.
  Future<void> _resyncCatalog() async {
    try {
      final onboardingService = ref.read(onboardingStatusServiceProvider);
      final countryCode = await onboardingService.getCountryCode();
      final accountType = await onboardingService.getAccountType();
      final changed = await CatalogSyncService().resyncOperators(
        countryCode: countryCode,
        accountType: accountType,
      );
      if (changed > 0) {
        debugPrint('[MoneyTracking] Catalogue resynchronisé : $changed pattern(s) mis à jour');
      }
    } catch (e) {
      debugPrint('[MoneyTracking] Resync catalogue ERROR: $e');
    }
  }

  /// Demande les permissions puis démarre l'écoute SMS. Au tout premier
  /// besoin, on explique POURQUOI l'app a besoin des SMS avant d'ouvrir le
  /// dialog système (permission priming) — un octroi accordé en contexte est
  /// bien plus fréquent qu'un dialog système surgi sans explication.
  Future<void> _initPermissionsAndSms() async {
    try {
      if (await PermissionService.hasSmsPermissions()) {
        await _startSmsListening();
        return;
      }
      if (await PermissionService.isSmsPermanentlyDenied()) return;

      final prefs = await SharedPreferences.getInstance();
      final primingShown = prefs.getBool('sms_priming_shown') ?? false;
      if (!primingShown) {
        await prefs.setBool('sms_priming_shown', true);
        final proceed = await _showSmsPrimingDialog();
        if (proceed != true) return; // "Plus tard" — re-tenté au resume
      }

      final granted = await PermissionService.requestSmsPermissions();
      debugPrint('[MoneyTracking] Permissions SMS: $granted');
      if (granted) {
        await _startSmsListening();
      }
    } catch (e) {
      debugPrint('[MoneyTracking] Permissions ERROR: $e');
    }
    await _primeBatteryOptimizationForExistingInstalls();
  }

  /// Pour un compte déjà onboardé AVANT l'introduction de cette demande
  /// (mise à jour d'une install existante) : les nouvelles installs la
  /// voient déjà en toute fin d'onboarding
  /// (OnboardingScreen._completeOnboarding). Ici, one-shot (même clé de
  /// préférence que côté onboarding n'est pas partagée exprès : l'un ou
  /// l'autre chemin s'exécute pour un compte donné, jamais les deux), et
  /// seulement une fois l'onboarding déjà terminé — sinon l'écran
  /// d'onboarding est encore affiché et gère lui-même cette demande.
  Future<void> _primeBatteryOptimizationForExistingInstalls() async {
    try {
      final onboarded =
          await ref.read(onboardingStatusServiceProvider).isComplete();
      if (!onboarded) return;
      if (await BatteryOptimizationHelper.hasExemption()) return;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('battery_priming_shown') ?? false) return;
      await prefs.setBool('battery_priming_shown', true);

      final ctx = await _waitForNavigatorContext();
      if (ctx == null || !ctx.mounted) return;
      await BatteryOptimizationHelper.requestExemption(ctx);
    } catch (e) {
      debugPrint('[MoneyTracking] Priming batterie ERROR: $e');
    }
  }

  Future<BuildContext?> _waitForNavigatorContext() async {
    final completer = Completer<BuildContext?>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete(
        ref.read(routerProvider).routerDelegate.navigatorKey.currentContext,
      );
    });
    return completer.future;
  }

  /// Explique l'usage des SMS avant le dialog système. Renvoie `true` si
  /// l'utilisateur accepte de continuer vers la demande de permission.
  Future<bool?> _showSmsPrimingDialog() async {
    final completer = Completer<bool?>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ctx = ref
          .read(routerProvider)
          .routerDelegate
          .navigatorKey
          .currentContext;
      if (ctx == null || !ctx.mounted) {
        completer.complete(false);
        return;
      }
      final result = await showDialog<bool>(
        context: ctx,
        builder: (d) => AlertDialog(
          title: const Text('Détection automatique de vos transactions'),
          content: const Text(
            'MoneyTracking lit les SMS de vos opérateurs Mobile Money '
            '(Orange, Moov, Coris, Wave…) pour enregistrer vos transactions '
            'automatiquement — sans saisie manuelle.\n\n'
            'Les SMS sont analysés uniquement sur votre téléphone. Aucun '
            'message n\'est envoyé ni partagé.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(d).pop(false),
              child: const Text('Plus tard'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(d).pop(true),
              child: const Text('Continuer'),
            ),
          ],
        ),
      );
      completer.complete(result);
    });
    return completer.future;
  }

  /// Démarre l'écoute SMS temps réel + le handler arrière-plan. Idempotent
  /// (`_smsListenersRegistered`) car appelé à la fois au premier lancement
  /// et, si les permissions n'étaient pas encore accordées à ce moment-là,
  /// à chaque retour au premier plan (`didChangeAppLifecycleState`) tant
  /// qu'elles ne l'ont pas été.
  Future<void> _startSmsListening() async {
    if (_smsListenersRegistered) return;
    _smsListenersRegistered = true;

    final smsService = SmsListenerService();
    smsService.onTransactionDetected = (_) {
      // Rafraîchir TOUT après détection SMS — le push sync est déjà
      // déclenché par le pipeline lui-même (sms_processing_pipeline.dart),
      // partagé avec le chemin headless (app fermée).
      ref.read(transactionsProvider.notifier).loadTransactions();
      ref.read(pendingTransactionsProvider.notifier).loadPending();
      ref.invalidate(dashboardStatsProvider(null));
      ref.invalidate(particulierDashboardProvider);
      ref.invalidate(recentActivityProvider);
      ref.invalidate(commissionsStatsProvider);
      ref.invalidate(uncategorizedCountProvider);
      ref.invalidate(recurringPaymentsProvider);
      ref.read(caissesProvider.notifier).load();
    };
    await smsService.startListening();
    ref.read(smsServiceActiveProvider.notifier).state = true;
    markSmsForegroundAlive();
    debugPrint('[MoneyTracking] SMS listener démarré');

    // Détection en arrière-plan (app fermée) via l'isolate headless
    // `another_telephony` — onNewMessage reste un no-op : le temps réel
    // premier plan est déjà couvert par SmsListenerService ci-dessus,
    // pas besoin de traiter deux fois le même SMS.
    Telephony.instance.listenIncomingSms(
      onNewMessage: (_) {},
      onBackgroundMessage: backgroundSmsHandler,
      listenInBackground: true,
    );
    debugPrint('[MoneyTracking] SMS background handler enregistré');

    // Rattrapage silencieux des SMS reçus pendant que l'app était fermée
    // (D15) — non-bloquant, aucune UI d'attente.
    unawaited(SmsCatchupService().run());
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[MoneyTracking] build()');
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'MoneyTracking',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [Locale('fr', 'FR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
