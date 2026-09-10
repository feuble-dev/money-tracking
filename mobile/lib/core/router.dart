import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/lock_screen.dart';
import '../features/auth/screens/setup_pin_screen.dart';
import '../features/auth/screens/change_pin_screen.dart';
import '../features/auth/screens/lock_timeout_screen.dart';
import '../features/backup/screens/backup_screen.dart';
import '../features/backup/screens/restore_screen.dart';
import '../features/caisse/screens/caisse_screen.dart';
import '../features/clients/screens/client_detail_screen.dart';
import '../features/clients/screens/client_form_screen.dart';
import '../features/clients/screens/clients_list_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/dashboard/screens/settings_screen.dart';
import '../features/dashboard/screens/sms_journal_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/dashboard/screens/sms_test_screen.dart';
import '../features/commissions/screens/commissions_screen.dart';
import '../features/agences/screens/mes_agences_screen.dart';
import '../features/agences/screens/mes_telephones_screen.dart';
import '../features/agences/screens/agence_sync_detail_screen.dart';
import '../features/export/screens/export_csv_screen.dart';
import '../features/export/screens/export_pdf_screen.dart';
import '../features/operators/screens/operator_form_screen.dart';
import '../features/operators/screens/sms_config_screen.dart';
import '../features/transactions/screens/new_transaction_screen.dart';
import '../features/transactions/screens/pending_list_screen.dart';
import '../features/transactions/screens/pending_transaction_screen.dart';
import '../features/transactions/screens/cancelled_transactions_screen.dart';
import '../features/transactions/screens/transactions_list_screen.dart';
import '../shared/widgets/main_shell.dart';
import 'historique/screens/import_historique_screen.dart';
import 'licence/screens/activation_screen.dart';
import 'licence/screens/licence_status_screen.dart';
import 'onboarding/onboarding_state.dart';
import 'onboarding/screens/onboarding_screen.dart';

/// Clé de navigation globale
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Provider pour le routeur GoRouter
final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  final isPinSetAsync = ref.watch(isPinSetProvider);
  final isPinSet = isPinSetAsync.valueOrNull ?? false;
  final isOnboardingCompleteAsync = ref.watch(isOnboardingCompleteProvider);
  final isOnboardingComplete = isOnboardingCompleteAsync.valueOrNull ?? false;
  final accountType = ref.watch(accountTypeProvider).valueOrNull ?? 'agence';

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final currentPath = state.matchedLocation;
      final isAuthRoute =
          currentPath == '/setup-pin' || currentPath == '/lock';

      // Route racine → rediriger vers dashboard
      if (currentPath == '/') return '/dashboard';

      // Premier lancement : catalogue/agence avant même le PIN, car les
      // données doivent déjà exister quand l'agent commence à s'en servir.
      if (!isOnboardingComplete) {
        return currentPath == '/onboarding' ? null : '/onboarding';
      }

      if (!isPinSet) {
        return isAuthRoute ? null : '/setup-pin';
      }

      if (!isAuthenticated) {
        return isAuthRoute ? null : '/lock';
      }

      if (isAuthRoute || currentPath == '/onboarding') {
        return '/dashboard';
      }

      // Commissions n'a pas de sens pour un compte Particulier (pas de
      // notion de commission, D7) — masqué du shell ET bloqué en accès
      // direct (deep link, ancien favori, etc.).
      if (accountType == 'particulier' && currentPath == '/commissions') {
        return '/dashboard';
      }

      // Gestion des clients réservée aux comptes Agence (D18) — masquée du
      // tiroir ET bloquée en accès direct.
      if (accountType == 'particulier' && currentPath.startsWith('/clients')) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      // Onboarding
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),

      // Auth routes
      GoRoute(
        path: '/setup-pin',
        builder: (context, state) => const SetupPinScreen(),
      ),
      GoRoute(
        path: '/lock',
        builder: (context, state) => const LockScreen(),
      ),

      // Navigation principale avec shell (3 onglets)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/transactions',
                builder: (context, state) =>
                    const TransactionsListScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/commissions',
                builder: (context, state) => const CommissionsScreen(),
              ),
            ],
          ),
        ],
      ),

      // Paramètres
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/caisse',
        builder: (context, state) => const CaisseScreen(),
      ),
      GoRoute(
        path: '/settings/backup',
        builder: (context, state) => const BackupScreen(),
      ),
      GoRoute(
        path: '/settings/restore',
        builder: (context, state) => const RestoreScreen(),
      ),

      GoRoute(
        path: '/settings/sms-journal',
        builder: (context, state) => const SmsJournalScreen(),
      ),
      GoRoute(
        path: '/settings/sms-test',
        builder: (context, state) => const SmsTestScreen(),
      ),

      // Notifications
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),

      // Multi-agence (D-affiliation) — vue "patron" en lecture seule
      GoRoute(
        path: '/agences/mes-agences',
        builder: (context, state) => const MesAgencesScreen(),
      ),
      GoRoute(
        path: '/agences/mes-agences/:id',
        builder: (context, state) => AgenceSyncDetailScreen(
          agenceId: int.parse(state.pathParameters['id']!),
          title: state.uri.queryParameters['title'],
        ),
      ),

      // Multi-téléphone Particulier — même mécanisme D-affiliation, jamais
      // de vocabulaire "agence" côté UI (D7).
      GoRoute(
        path: '/telephones/mes-telephones',
        builder: (context, state) => const MesTelephonesScreen(),
      ),

      // Export
      GoRoute(
        path: '/export/pdf',
        builder: (context, state) => const ExportPdfScreen(),
      ),
      GoRoute(
        path: '/export/csv',
        builder: (context, state) => const ExportCsvScreen(),
      ),

      // Transactions — plus de dichotomie dépôt/retrait dans la route :
      // l'opérateur puis son type sont choisis dans l'écran lui-même (D3).
      GoRoute(
        path: '/transactions/new',
        builder: (context, state) => const NewTransactionScreen(),
      ),
      GoRoute(
        path: '/transactions/pending',
        builder: (context, state) => const PendingListScreen(),
      ),
      GoRoute(
        path: '/transactions/pending/:id',
        builder: (context, state) {
          return PendingTransactionScreen(
              transactionId: state.pathParameters['id']!);
        },
      ),
      GoRoute(
        path: '/transactions/cancelled',
        builder: (context, state) => const CancelledTransactionsScreen(),
      ),

      // Opérateurs
      GoRoute(
        path: '/operators/add',
        builder: (context, state) => const OperatorFormScreen(),
      ),
      GoRoute(
        path: '/operators/edit/:id',
        builder: (context, state) {
          return OperatorFormScreen(
              operatorId: state.pathParameters['id']);
        },
      ),
      GoRoute(
        path: '/operators/:id/sms-config',
        builder: (context, state) {
          return SmsConfigScreen(
              operatorId: state.pathParameters['id']!);
        },
      ),

      // Clients (accessible depuis le sidebar)
      GoRoute(
        path: '/clients',
        builder: (context, state) => const ClientsListScreen(),
      ),
      GoRoute(
        path: '/clients/add',
        builder: (context, state) => const ClientFormScreen(),
      ),
      GoRoute(
        path: '/clients/edit/:id',
        builder: (context, state) {
          return ClientFormScreen(clientId: state.pathParameters['id']);
        },
      ),
      GoRoute(
        path: '/clients/:id',
        builder: (context, state) {
          return ClientDetailScreen(
              clientId: state.pathParameters['id']!);
        },
      ),

      // Sécurité
      GoRoute(
        path: '/security/change-pin',
        builder: (context, state) => const ChangePinScreen(),
      ),
      GoRoute(
        path: '/security/lock-timeout',
        builder: (context, state) => const LockTimeoutScreen(),
      ),

      // Licence
      GoRoute(
        path: '/activation',
        builder: (context, state) => const ActivationScreen(),
      ),
      GoRoute(
        path: '/licence/statut',
        builder: (context, state) => const LicenceStatusScreen(),
      ),
      GoRoute(
        path: '/historique/import',
        builder: (context, state) => const ImportHistoriqueScreen(),
      ),
    ],
  );
});
