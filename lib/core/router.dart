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
import '../features/export/screens/export_csv_screen.dart';
import '../features/export/screens/export_pdf_screen.dart';
import '../features/operators/screens/operator_form_screen.dart';
import '../features/operators/screens/sms_config_screen.dart';
import '../features/transactions/screens/new_transaction_screen.dart';
import '../features/transactions/screens/pending_list_screen.dart';
import '../features/transactions/screens/pending_transaction_screen.dart';
import '../features/transactions/screens/transactions_list_screen.dart';
import '../shared/widgets/main_shell.dart';

/// Clé de navigation globale
final rootNavigatorKey = GlobalKey<NavigatorState>();

/// Provider pour le routeur GoRouter
final routerProvider = Provider<GoRouter>((ref) {
  final isAuthenticated = ref.watch(isAuthenticatedProvider);
  final isPinSetAsync = ref.watch(isPinSetProvider);
  final isPinSet = isPinSetAsync.valueOrNull ?? false;

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/dashboard',
    redirect: (context, state) {
      final currentPath = state.matchedLocation;
      final isAuthRoute =
          currentPath == '/setup-pin' || currentPath == '/lock';

      // Route racine → rediriger vers dashboard
      if (currentPath == '/') return '/dashboard';

      if (!isPinSet) {
        return isAuthRoute ? null : '/setup-pin';
      }

      if (!isAuthenticated) {
        return isAuthRoute ? null : '/lock';
      }

      if (isAuthRoute) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
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

      // Export
      GoRoute(
        path: '/export/pdf',
        builder: (context, state) => const ExportPdfScreen(),
      ),
      GoRoute(
        path: '/export/csv',
        builder: (context, state) => const ExportCsvScreen(),
      ),

      // Transactions
      GoRoute(
        path: '/transactions/new/:type',
        builder: (context, state) {
          final type = state.pathParameters['type'] ?? 'deposit';
          return NewTransactionScreen(transactionType: type);
        },
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
    ],
  );
});
