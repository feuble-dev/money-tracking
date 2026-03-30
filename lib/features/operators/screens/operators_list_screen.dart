import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/operator_provider.dart';
import '../models/operator_model.dart';
import '../../../core/theme/app_colors.dart';

/// Écran liste des opérateurs
class OperatorsListScreen extends ConsumerWidget {
  const OperatorsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operatorsAsync = ref.watch(operatorsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Opérateurs'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/operators/add'),
        child: const Icon(Icons.add),
      ),
      body: operatorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (operators) {
          if (operators.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.business, size: 80, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'Aucun opérateur configuré',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 8),
                  const Text('Ajoutez votre premier opérateur'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: operators.length,
            itemBuilder: (context, index) =>
                _OperatorCard(operator_: operators[index]),
          );
        },
      ),
    );
  }
}

class _OperatorCard extends ConsumerWidget {
  final OperatorModel operator_;

  const _OperatorCard({required this.operator_});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: AppColors.primaryColor.withAlpha(30),
          child: Text(
            operator_.name.substring(0, 2).toUpperCase(),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryColor,
            ),
          ),
        ),
        title: Text(
          operator_.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (operator_.agentNumber != null)
              Text('Agent: ${operator_.agentNumber}'),
            if (operator_.accountNumber != null)
              Text('Compte: ${operator_.accountNumber}'),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Badge actif/inactif
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: operator_.isActive
                    ? AppColors.depositColor.withAlpha(30)
                    : Colors.grey.withAlpha(30),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                operator_.isActive ? 'Actif' : 'Inactif',
                style: TextStyle(
                  fontSize: 12,
                  color: operator_.isActive
                      ? AppColors.depositColor
                      : Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () => context.push('/operators/edit/${operator_.id}'),
      ),
    );
  }
}
