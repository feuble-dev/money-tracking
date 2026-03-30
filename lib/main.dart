import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/database/database_helper.dart';
import 'core/notifications/notification_service.dart';
import 'core/permissions/permission_service.dart';
import 'core/router.dart';
import 'core/sms/sms_listener.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_notifier.dart';
import 'features/transactions/providers/transaction_provider.dart';
import 'features/dashboard/providers/dashboard_provider.dart';

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

class _MoneyTrackingAppState extends ConsumerState<MoneyTrackingApp> {
  @override
  void initState() {
    super.initState();
    debugPrint('[MoneyTracking] initState');
    _initPermissionsAndSms();
    _initNotificationHandler();
  }

  @override
  void dispose() {
    SmsListenerService().stopListening();
    NotificationService().onNotificationTapped = null;
    super.dispose();
  }

  /// Gère le tap sur une notification
  /// Si la transaction a un client → va sur les transactions
  /// Si pas de client → ouvre le formulaire d'ajout client
  void _initNotificationHandler() {
    final notifService = NotificationService();
    notifService.onNotificationTapped = (payload) {
      if (payload == null) return;
      final router = ref.read(routerProvider);
      router.push('/notifications');
    };
    // Quand une action est effectuée depuis la notif (confirmer/rejeter)
    notifService.onActionPerformed = () {
      ref.read(transactionsProvider.notifier).loadTransactions();
      ref.read(pendingTransactionsProvider.notifier).loadPending();
      ref.invalidate(dashboardStatsProvider(null));
    };
  }

  /// Demande les permissions puis démarre l'écoute SMS
  Future<void> _initPermissionsAndSms() async {
    try {
      final granted = await PermissionService.requestSmsPermissions();
      debugPrint('[MoneyTracking] Permissions SMS: $granted');
      if (granted) {
        final smsService = SmsListenerService();
        smsService.onTransactionDetected = (_) {
          // Rafraîchir toutes les listes après détection SMS
          ref.read(transactionsProvider.notifier).loadTransactions();
          ref.read(pendingTransactionsProvider.notifier).loadPending();
          ref.invalidate(dashboardStatsProvider(null));
        };
        await smsService.startListening();
        ref.read(smsServiceActiveProvider.notifier).state = true;
        debugPrint('[MoneyTracking] SMS listener démarré');
      }
    } catch (e) {
      debugPrint('[MoneyTracking] Permissions ERROR: $e');
    }
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
