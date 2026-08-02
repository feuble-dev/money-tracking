import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/operator_avatar.dart';
import '../../operators/providers/operator_provider.dart';
import '../providers/caisse_provider.dart';

/// Écran de gestion de la caisse
class CaisseScreen extends ConsumerStatefulWidget {
  const CaisseScreen({super.key});

  @override
  ConsumerState<CaisseScreen> createState() => _CaisseScreenState();
}

class _CaisseScreenState extends ConsumerState<CaisseScreen> {
  final _currencyFormat =
      NumberFormat.currency(locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  @override
  Widget build(BuildContext context) {
    final caissesAsync = ref.watch(caissesProvider);
    final operatorsAsync = ref.watch(operatorsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Gestion de la caisse')),
      body: caissesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (caisses) {
          return operatorsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (operators) {
              final activeOps = operators.where((o) => o.isActive).toList();

              // Opérateurs sans caisse configurée
              final opsWithoutCaisse = activeOps.where((op) =>
                  !caisses.any((c) => c.operatorId == op.id)).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Solde global
                  _buildGlobalCard(caisses),
                  const SizedBox(height: 16),

                  // Caisses par opérateur
                  ...caisses.map((caisse) =>
                      _buildCaisseCard(context, caisse)),

                  // Opérateurs sans caisse
                  if (opsWithoutCaisse.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Configurer la caisse',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            )),
                    const SizedBox(height: 8),
                    ...opsWithoutCaisse.map((op) => Card(
                          child: ListTile(
                            leading: OperatorAvatar(
                              name: op.name,
                              logoPath: op.logoPath,
                              radius: 20,
                            ),
                            title: Text(op.name),
                            subtitle:
                                const Text('Caisse non configurée'),
                            trailing: ElevatedButton(
                              onPressed: () =>
                                  _showInitDialog(context, op.id, op.name),
                              child: const Text('Configurer'),
                            ),
                          ),
                        )),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGlobalCard(List<CaisseModel> caisses) {
    double totalSolde = 0;
    for (final c in caisses) {
      totalSolde += c.soldeActuel;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryColor, AppColors.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Solde global',
              style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            _currencyFormat.format(totalSolde),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text('${caisses.length} caisse(s) configurée(s)',
              style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildCaisseCard(BuildContext context, CaisseModel caisse) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  caisse.operatorName ?? 'Opérateur',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 16),
                ),
                const Spacer(),
                if (caisse.isAlerte)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber, color: Colors.red, size: 14),
                        SizedBox(width: 4),
                        Text('Seuil bas',
                            style:
                                TextStyle(color: Colors.red, fontSize: 11)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Solde actuel',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text(_currencyFormat.format(caisse.soldeActuel),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: caisse.isAlerte
                                ? Colors.red
                                : AppColors.withdrawColor,
                          )),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Seuil alerte',
                          style: Theme.of(context).textTheme.bodySmall),
                      Text(_currencyFormat.format(caisse.seuilAlerte),
                          style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showRechargeDialog(
                        context, caisse.operatorId!, caisse.operatorName!),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Recharger'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showInitDialog(
                        context, caisse.operatorId!, caisse.operatorName!),
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Modifier'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showInitDialog(
      BuildContext context, String operatorId, String operatorName) {
    final soldeCtrl = TextEditingController();
    final seuilCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Caisse $operatorName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: soldeCtrl,
              decoration: const InputDecoration(labelText: 'Solde initial (FCFA)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: seuilCtrl,
              decoration:
                  const InputDecoration(labelText: 'Seuil d\'alerte (FCFA)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final solde =
                  double.tryParse(soldeCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ??
                      0;
              final seuil =
                  double.tryParse(seuilCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ??
                      0;
              await ref.read(caissesProvider.notifier).initCaisse(
                    operatorId: operatorId,
                    soldeInitial: solde,
                    seuilAlerte: seuil,
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  void _showRechargeDialog(
      BuildContext context, String operatorId, String operatorName) {
    final montantCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Recharger $operatorName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: montantCtrl,
              decoration: const InputDecoration(labelText: 'Montant (FCFA)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optionnel)'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () async {
              final montant = double.tryParse(
                      montantCtrl.text.replaceAll(RegExp(r'[^\d]'), '')) ??
                  0;
              if (montant > 0) {
                await ref.read(caissesProvider.notifier).recharger(
                      operatorId: operatorId,
                      montant: montant,
                      note: noteCtrl.text.trim().isEmpty
                          ? null
                          : noteCtrl.text.trim(),
                    );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Recharger'),
          ),
        ],
      ),
    );
  }
}
