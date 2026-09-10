import 'package:uuid/uuid.dart';
import 'database_helper.dart';

const _uuid = Uuid();

/// Mise à jour du solde caisse, indépendante de Riverpod — utilisée par les
/// chemins qui ne tournent pas dans un widget tree (pipeline SMS temps réel
/// ET headless, import historique). `CaissesNotifier.updateSoldeAfterTransaction`
/// (caisse_provider.dart) délègue ici puis rafraîchit son état pour l'UI ;
/// ce repository est la seule source de vérité pour la logique elle-même.
class CaisseRepository {
  /// Deux modes selon ce que la transaction a pu fournir :
  ///
  /// - [soldeApres] connu (le SMS annonce le solde réel après l'opération,
  ///   ex: "Votre solde est de 15209.69 FCFA") : on ÉCRASE solde_actuel avec
  ///   cette valeur — c'est la seule source de vérité, jamais une somme de
  ///   deltas (qui dérive au moindre SMS manqué/mal parsé). Protégé contre le
  ///   désordre (import historique, redélivrance) par [transactionAt] : un
  ///   SMS plus ancien que le dernier solde déjà connu est ignoré, pour ne
  ///   jamais écraser une valeur plus récente donc plus vraie. Si aucune
  ///   caisse n'existe encore pour cet opérateur, elle est créée directement
  ///   avec ce solde annoncé comme référence — inutile d'attendre que
  ///   l'agent clique "Configurer" pour que le solde réel apparaisse au
  ///   tableau de bord, alors que le SMS vient justement de le donner.
  /// - [soldeApres] absent (transaction manuelle, aucun SMS ne le rapporte) :
  ///   on retombe sur un ajustement delta (+/- amount) relatif au dernier
  ///   solde connu — mais seulement si une caisse existe déjà, faute de
  ///   référence de départ pour en créer une.
  ///
  /// direction='in' (l'argent du client augmente, ex-dépôt) : solde diminue.
  /// direction='out' (l'argent du client diminue, ex-retrait) : solde augmente.
  static Future<void> updateSoldeAfterTransaction({
    required String operatorId,
    required double amount,
    required String direction,
    double? soldeApres,
    DateTime? transactionAt,
  }) async {
    final db = await DatabaseHelper.instance.database;
    final existing = await db.query('caisse',
        where: 'operator_id = ?', whereArgs: [operatorId]);

    if (existing.isEmpty) {
      if (soldeApres == null) return;
      final at = transactionAt ?? DateTime.now();
      await db.insert('caisse', {
        'id': _uuid.v4(),
        'operator_id': operatorId,
        'solde_initial': soldeApres,
        'solde_actuel': soldeApres,
        'solde_ref_at': at.toIso8601String(),
        'seuil_alerte': 0,
        'updated_at': DateTime.now().toIso8601String(),
      });
      return;
    }

    if (soldeApres != null) {
      final refAtStr = existing.first['solde_ref_at'] as String?;
      final refAt = refAtStr != null ? DateTime.tryParse(refAtStr) : null;
      final at = transactionAt ?? DateTime.now();
      if (refAt != null && !at.isAfter(refAt)) {
        return;
      }
      await db.rawUpdate(
        'UPDATE caisse SET solde_actuel = ?, solde_ref_at = ?, updated_at = ? WHERE operator_id = ?',
        [soldeApres, at.toIso8601String(), DateTime.now().toIso8601String(), operatorId],
      );
      return;
    }

    final delta = direction == 'in' ? -amount : amount;
    await db.rawUpdate(
      'UPDATE caisse SET solde_actuel = solde_actuel + ?, updated_at = ? WHERE operator_id = ?',
      [delta, DateTime.now().toIso8601String(), operatorId],
    );
  }
}
