import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/licence/licence_storage.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../transactions/providers/transaction_provider.dart';

// ── URL backend (même que licence_service) ──
const String _baseUrl = 'https://api.money-tracking.site/api/licence';
// const String _baseUrl = 'http://localhost:8000/api/licence';

/// Provider: transactions SMS récentes (utilise la vue optimisée)
final recentActivityProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await DatabaseHelper.instance.database;
  return db.rawQuery('''
    SELECT * FROM v_transactions_with_operator
    WHERE source = 'sms_auto' AND status NOT IN ('rejected')
    ORDER BY created_at DESC
    LIMIT 50
  ''');
});

/// Provider: notifications générales depuis le backend
final generalNotificationsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final db = await DatabaseHelper.instance.database;

  // Tenter de fetch depuis le backend
  try {
    final telephone = await LicenceStorage.getTelephone();
    debugPrint('[Notifs] Téléphone: $telephone');
    if (telephone != null && telephone.isNotEmpty) {
      // Construire l'URL correctement
      final url = '$_baseUrl/notifications/?telephone=$telephone';
      debugPrint('[Notifs] Fetch: $url');
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      debugPrint(
        '[Notifs] Response: ${resp.statusCode} body=${resp.body.length} chars',
      );
      if (resp.statusCode == 200) {
        final List<dynamic> data = jsonDecode(resp.body);
        debugPrint('[Notifs] ${data.length} notifications reçues');
        final now = DateTime.now().toIso8601String();
        for (final n in data) {
          // Vérifier si cette notif est déjà en base
          final existing = await db.query(
            'general_notifications',
            where: 'id = ?',
            whereArgs: [n['id']],
            limit: 1,
          );
          if (existing.isEmpty) {
            // Nouvelle notif → insérer + notification Android
            await db.insert('general_notifications', {
              'id': n['id'],
              'titre': n['titre'],
              'message': n['message'],
              'cible': n['cible'] ?? 'all',
              'is_read': 0,
              'created_at': n['created_at'],
              'fetched_at': now,
            });
            // Afficher notification Android
            await NotificationService().showGeneralNotification(
              id: n['id'] as int,
              titre: n['titre'] as String,
              message: n['message'] as String,
            );
          }
        }
      }
    }
  } catch (e) {
    debugPrint('[Notifs] Erreur fetch: $e');
  }

  try {
    return await db.rawQuery('''
      SELECT * FROM general_notifications
      ORDER BY created_at DESC
      LIMIT 100
    ''');
  } catch (e) {
    debugPrint('[Notifs] Table general_notifications inexistante: $e');
    // Créer la table si elle n'existe pas (migration pas encore passée)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS general_notifications (
        id INTEGER PRIMARY KEY,
        titre TEXT NOT NULL,
        message TEXT NOT NULL,
        cible TEXT DEFAULT 'all',
        is_read INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        fetched_at TEXT NOT NULL
      )
    ''');
    return [];
  }
});

/// Provider: nombre de notifs générales non lues
final unreadGeneralCountProvider = Provider<int>((ref) {
  final notifs = ref.watch(generalNotificationsProvider);
  return notifs.valueOrNull?.where((n) => n['is_read'] == 0).length ?? 0;
});

/// Provider: nombre de transactions pending
final pendingNotifCountProvider = Provider<int>((ref) {
  final activity = ref.watch(recentActivityProvider);
  return activity.valueOrNull
          ?.where((tx) => tx['status'] == 'pending')
          .length ??
      0;
});

/// Écran notifications avec 2 onglets
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Auto-refresh à l'ouverture
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(recentActivityProvider);
      ref.invalidate(generalNotificationsProvider);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = ref.watch(pendingNotifCountProvider);
    final unreadCount = ref.watch(unreadGeneralCountProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(recentActivityProvider);
              ref.invalidate(generalNotificationsProvider);
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Transactions'),
                  if (pendingCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accentColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$pendingCount',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Général'),
                  if (unreadCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_TransactionsTab(), _GeneralTab()],
      ),
    );
  }
}

// ── Onglet Transactions ──────────────────────────────────────
class _TransactionsTab extends ConsumerWidget {
  final dateFormat = DateFormat('dd/MM HH:mm', 'fr_FR');
  final currencyFormat = NumberFormat.currency(
    locale: 'fr_FR',
    symbol: 'FCFA',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityAsync = ref.watch(recentActivityProvider);

    return activityAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (activities) {
        if (activities.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'Aucune transaction SMS',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: activities.length,
          itemBuilder: (context, index) {
            final tx = activities[index];
            final isDeposit = tx['direction'] != null
                ? tx['direction'] == 'in'
                : tx['transaction_type'] == 'deposit';
            final color = isDeposit
                ? AppColors.depositColor
                : AppColors.withdrawColor;
            final typeLabel =
                (tx['type_label'] as String?) ??
                (tx['transaction_type'] == 'deposit' ? 'Dépôt' : 'Retrait');
            final amount = (tx['amount'] as num).toDouble();
            final clientName = tx['client_name'] as String?;
            final clientPhone = tx['client_phone'] as String? ?? '';
            final operatorName = tx['operator_name'] as String? ?? '';
            final createdAt = DateTime.parse(tx['created_at'] as String);
            final txId = tx['id'] as String;
            final status = tx['status'] as String? ?? 'pending';
            final isPending = status == 'pending';

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  context.push('/transactions/pending/$txId').then((_) {
                    ref.invalidate(recentActivityProvider);
                    ref.read(transactionsProvider.notifier).loadTransactions();
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isDeposit ? Icons.arrow_downward : Icons.arrow_upward,
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$typeLabel - $operatorName',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: color,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              clientName ?? clientPhone,
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              dateFormat.format(createdAt),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            currencyFormat.format(amount),
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: color,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: isPending
                                  ? Colors.orange.withAlpha(20)
                                  : AppColors.depositColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              isPending ? 'En attente' : 'Confirmé',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isPending
                                    ? Colors.orange
                                    : AppColors.depositColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ── Onglet Général ───────────────────────────────────────────
class _GeneralTab extends ConsumerWidget {
  final dateFormat = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifsAsync = ref.watch(generalNotificationsProvider);

    return notifsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erreur: $e')),
      data: (notifs) {
        if (notifs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune notification',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les notifications envoyées par\nl\'administrateur apparaîtront ici.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[400], fontSize: 13),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: notifs.length,
          itemBuilder: (context, index) {
            final n = notifs[index];
            final isRead = n['is_read'] == 1;
            final createdAt = DateTime.parse(n['created_at'] as String);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              color: isRead ? null : AppColors.primaryColor.withAlpha(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () async {
                  // Marquer comme lu
                  if (!isRead) {
                    final db = await DatabaseHelper.instance.database;
                    await db.update(
                      'general_notifications',
                      {'is_read': 1},
                      where: 'id = ?',
                      whereArgs: [n['id']],
                    );
                    ref.invalidate(generalNotificationsProvider);
                  }
                  if (!context.mounted) return;
                  // Afficher le message complet
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(
                        n['titre'] as String,
                        style: const TextStyle(fontSize: 16),
                      ),
                      content: Text(n['message'] as String),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Fermer'),
                        ),
                      ],
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isRead
                              ? Colors.grey.withAlpha(20)
                              : AppColors.primaryColor.withAlpha(20),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isRead
                              ? Icons.notifications_none
                              : Icons.notifications_active,
                          color: isRead ? Colors.grey : AppColors.primaryColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              n['titre'] as String,
                              style: TextStyle(
                                fontWeight: isRead
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              n['message'] as String,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dateFormat.format(createdAt),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
