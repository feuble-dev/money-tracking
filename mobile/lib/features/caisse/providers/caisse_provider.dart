import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/database/caisse_repository.dart';
import '../../../core/database/database_helper.dart';

const _uuid = Uuid();

/// Modèle de caisse
class CaisseModel {
  final String id;
  final String? operatorId;
  final String? operatorName;
  final double soldeInitial;
  final double soldeActuel;
  final double seuilAlerte;

  CaisseModel({
    required this.id,
    this.operatorId,
    this.operatorName,
    this.soldeInitial = 0,
    this.soldeActuel = 0,
    this.seuilAlerte = 0,
  });

  factory CaisseModel.fromMap(Map<String, dynamic> map) => CaisseModel(
        id: map['id'] as String,
        operatorId: map['operator_id'] as String?,
        operatorName: map['operator_name'] as String?,
        soldeInitial: (map['solde_initial'] as num?)?.toDouble() ?? 0,
        soldeActuel: (map['solde_actuel'] as num?)?.toDouble() ?? 0,
        seuilAlerte: (map['seuil_alerte'] as num?)?.toDouble() ?? 0,
      );

  bool get isAlerte => seuilAlerte > 0 && soldeActuel < seuilAlerte;
}

/// Modèle d'opération de caisse
class CaisseOperation {
  final String id;
  final String? operatorId;
  final String type; // 'rechargement' | 'ajustement'
  final double montant;
  final String? note;
  final DateTime createdAt;

  CaisseOperation({
    required this.id,
    this.operatorId,
    required this.type,
    required this.montant,
    this.note,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// Provider pour les caisses
final caissesProvider =
    StateNotifierProvider<CaissesNotifier, AsyncValue<List<CaisseModel>>>(
        (ref) => CaissesNotifier());

class CaissesNotifier extends StateNotifier<AsyncValue<List<CaisseModel>>> {
  CaissesNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.rawQuery('''
        SELECT c.*, o.name as operator_name
        FROM caisse c
        LEFT JOIN operators o ON c.operator_id = o.id
        ORDER BY c.operator_id
      ''');
      state = AsyncValue.data(
          results.map((e) => CaisseModel.fromMap(e)).toList());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Initialiser ou mettre à jour la caisse d'un opérateur
  Future<void> initCaisse({
    required String operatorId,
    required double soldeInitial,
    double seuilAlerte = 0,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final existing = await db.query('caisse',
        where: 'operator_id = ?', whereArgs: [operatorId]);

    if (existing.isNotEmpty) {
      await db.update(
        'caisse',
        {
          'solde_initial': soldeInitial,
          'solde_actuel': soldeInitial,
          // Réinitialisation manuelle = nouvelle référence de vérité ; on
          // efface solde_ref_at pour que le prochain SMS avec solde annoncé
          // (même daté d'avant cette réinit) puisse s'appliquer normalement.
          'solde_ref_at': null,
          'seuil_alerte': seuilAlerte,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'operator_id = ?',
        whereArgs: [operatorId],
      );
    } else {
      await db.insert('caisse', {
        'id': _uuid.v4(),
        'operator_id': operatorId,
        'solde_initial': soldeInitial,
        'solde_actuel': soldeInitial,
        'seuil_alerte': seuilAlerte,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }
    await load();
  }

  /// Recharger la caisse
  Future<void> recharger({
    required String operatorId,
    required double montant,
    String? note,
  }) async {
    final db = await DatabaseHelper.instance.database;
    await db.rawUpdate(
      'UPDATE caisse SET solde_actuel = solde_actuel + ?, updated_at = ? WHERE operator_id = ?',
      [montant, DateTime.now().toIso8601String(), operatorId],
    );
    await db.insert('caisse_operations', {
      'id': _uuid.v4(),
      'operator_id': operatorId,
      'type': 'rechargement',
      'montant': montant,
      'note': note,
      'created_at': DateTime.now().toIso8601String(),
    });
    await load();
  }

  /// Met à jour le solde après une transaction.
  /// direction='in' (l'argent du client augmente, ex-dépôt) : solde diminue.
  /// direction='out' (l'argent du client diminue, ex-retrait) : solde augmente.
  /// Généralisé au sens (D1) plutôt qu'au libellé du type — fonctionne pour
  /// n'importe quel type de transaction, pas seulement dépôt/retrait.
  Future<void> updateSoldeAfterTransaction({
    required String operatorId,
    required double amount,
    required String direction,
  }) async {
    await CaisseRepository.updateSoldeAfterTransaction(
      operatorId: operatorId,
      amount: amount,
      direction: direction,
    );
    await load();
  }
}
