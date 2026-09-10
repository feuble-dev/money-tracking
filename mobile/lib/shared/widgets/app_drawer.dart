import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/onboarding/onboarding_state.dart';
import '../../core/theme/app_colors.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/operators/providers/operator_provider.dart';
import 'operator_avatar.dart';

/// Drawer latéral avec sections Opérateurs et Sécurité
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operatorsAsync = ref.watch(operatorsProvider);
    final accountType = ref.watch(accountTypeProvider).valueOrNull ?? 'agence';
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // En-tête avec logo
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 48,
                      height: 48,
                      errorBuilder: (_, _, _) => Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(30),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.account_balance_wallet,
                            color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MoneyTracking',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text(
                          'Gestion de transactions Mobile Money',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Contenu scrollable
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  // === SECTION OPÉRATEURS ===
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      'OPÉRATEURS',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  operatorsAsync.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))),
                    ),
                    error: (_, _) => const ListTile(
                      leading: Icon(Icons.error_outline),
                      title: Text('Erreur de chargement'),
                    ),
                    data: (operators) {
                      final activeOps =
                          operators.where((o) => o.isActive).toList();
                      return Column(
                        children: [
                          ...activeOps.map((op) => ListTile(
                                leading: OperatorAvatar(
                                  name: op.name,
                                  logoPath: op.logoPath,
                                  radius: 16,
                                ),
                                title: Text(op.name),
                                subtitle: op.accountNumber != null
                                    ? Text(op.accountNumber!,
                                        style: const TextStyle(fontSize: 11))
                                    : null,
                                dense: true,
                                onTap: () {
                                  Navigator.pop(context);
                                  context.push('/operators/edit/${op.id}');
                                },
                              )),
                          // Bouton ajouter opérateur
                          ListTile(
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor:
                                  AppColors.accentColor.withAlpha(20),
                              child: const Icon(Icons.add,
                                  size: 18, color: AppColors.accentColor),
                            ),
                            title: const Text('Ajouter un opérateur'),
                            dense: true,
                            onTap: () {
                              Navigator.pop(context);
                              context.push('/operators/add');
                            },
                          ),
                        ],
                      );
                    },
                  ),

                  // === SECTION CLIENTS === (Agence uniquement — D18 : un
                  // compte Particulier ne gère pas de clients)
                  if (accountType == 'agence') ...[
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'CLIENTS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.people_outline),
                      title: const Text('Liste des clients'),
                      dense: true,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/clients');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.person_add_outlined),
                      title: const Text('Ajouter un client'),
                      dense: true,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/clients/add');
                      },
                    ),
                  ],

                  if (accountType == 'agence') ...[
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'MULTI-AGENCE',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.store_outlined),
                      title: const Text('Mes agences'),
                      dense: true,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/agences/mes-agences');
                      },
                    ),
                  ] else if (accountType == 'particulier') ...[
                    const Divider(height: 24),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Text(
                        'FINANCES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.savings_outlined),
                      title: const Text('Budget & motifs'),
                      dense: true,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/budget');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.label_outline),
                      title: const Text('Catégoriser les dépenses'),
                      dense: true,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/categorize');
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.phone_android),
                      title: const Text('Mes téléphones'),
                      dense: true,
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/telephones/mes-telephones');
                      },
                    ),
                  ],

                  const Divider(height: 24),

                  // === SECTION SÉCURITÉ ===
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Text(
                      'SÉCURITÉ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.pin_outlined),
                    title: const Text('Modifier le PIN'),
                    dense: true,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/security/change-pin');
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.fingerprint),
                    title: const Text('Empreinte digitale'),
                    dense: true,
                    onTap: () {
                      Navigator.pop(context);
                      _showBiometricInfo(context, ref);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: const Text('Délai de verrouillage'),
                    dense: true,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/security/lock-timeout');
                    },
                  ),

                  const Divider(height: 24),

                  // Paramètres
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Paramètres'),
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/settings');
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showBiometricInfo(BuildContext context, WidgetRef ref) {
    final bioAvailable = ref.read(isBiometricAvailableProvider);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Empreinte digitale'),
        content: bioAvailable.when(
          data: (available) => Text(available
              ? 'La biométrie est activée et disponible sur cet appareil.'
              : 'La biométrie n\'est pas disponible. Vérifiez que vous avez '
                  'enregistré une empreinte dans les paramètres de votre téléphone.'),
          loading: () => const Text('Vérification...'),
          error: (_, _) =>
              const Text('Impossible de vérifier la biométrie.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
