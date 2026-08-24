import 'database_helper.dart';

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
  ///   jamais écraser une valeur plus récente donc plus vraie.
  /// - [soldeApres] absent (transaction manuelle, aucun SMS ne le rapporte) :
  ///   seul cas où on retombe sur un ajustement delta (+/- amount) relatif au
  ///   dernier solde connu.
  ///
  /// direction='in' (l'argent du client augmente, ex-dépôt) : solde diminue.
  /// direction='out' (l'argent du client diminue, ex-retrait) : solde augmente.
  /// No-op si aucune caisse n'a été initialisée pour cet opérateur (la
  /// caisse est une fonctionnalité opt-in, pas un suivi forcé).
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
    if (existing.isEmpty) return;

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
