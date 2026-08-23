/// Calcul de commission unique — remplace les 3 implémentations dupliquées
/// de `amount * taux / 100` (sms_listener.dart, historique_service.dart,
/// OperatorModel.calculateCommission).
class CommissionCalculator {
  static double compute({
    required double amount,
    required double commissionTaux,
  }) {
    return (amount * commissionTaux) / 100;
  }
}
