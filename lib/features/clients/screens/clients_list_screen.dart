import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/main_shell.dart';
import '../../operators/providers/operator_provider.dart';
import '../providers/client_provider.dart';

/// Écran liste des clients avec filtre opérateur
class ClientsListScreen extends ConsumerStatefulWidget {
  const ClientsListScreen({super.key});

  @override
  ConsumerState<ClientsListScreen> createState() => _ClientsListScreenState();
}

class _ClientsListScreenState extends ConsumerState<ClientsListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() {
    final search = _searchController.text.trim();
    final operatorId = ref.read(clientOperatorFilterProvider);
    ref.read(clientsProvider.notifier).loadClients(
      search: search.isEmpty ? null : search,
      operatorId: operatorId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(clientsProvider);
    final operatorsAsync = ref.watch(operatorsProvider);
    final selectedOpId = ref.watch(clientOperatorFilterProvider);

    return Scaffold(
      appBar: AppBar(
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
              ),
        title: const Text('Clients'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou numéro...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary.withAlpha(180),
                ),
                prefixIcon: Icon(Icons.search,
                    color: Theme.of(context).colorScheme.onPrimary.withAlpha(200)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.onPrimary.withAlpha(30),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              onChanged: (_) => _reload(),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/clients/add'),
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          // Filtre opérateur en chips
          operatorsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (operators) {
              final activeOps = operators.where((o) => o.isActive).toList();
              if (activeOps.isEmpty) return const SizedBox.shrink();

              return Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: ChoiceChip(
                        label: const Text('Tous', style: TextStyle(fontSize: 12)),
                        selected: selectedOpId == null,
                        onSelected: (_) {
                          ref.read(clientOperatorFilterProvider.notifier).state = null;
                          _reload();
                        },
                      ),
                    ),
                    ...activeOps.map((op) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      child: ChoiceChip(
                        label: Text(op.name, style: const TextStyle(fontSize: 12)),
                        selected: selectedOpId == op.id,
                        onSelected: (_) {
                          ref.read(clientOperatorFilterProvider.notifier).state = op.id;
                          _reload();
                        },
                      ),
                    )),
                  ],
                ),
              );
            },
          ),

          // Liste clients
          Expanded(
            child: clientsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Erreur: $e')),
              data: (clients) {
                if (clients.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 80, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('Aucun client',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(color: Colors.grey[600])),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  cacheExtent: 800,
                  addAutomaticKeepAlives: true,
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final client = clients[index];
                    return RepaintBoundary(
                      child: Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.primaryColor.withAlpha(30),
                            child: Text(
                              '${client.firstName[0]}${client.lastName[0]}'.toUpperCase(),
                              style: const TextStyle(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Text(client.fullName,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${client.phoneNumber}${client.operatorName != null ? ' — ${client.operatorName}' : ''}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/clients/${client.id}'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
