class LicenceValidator {
  // Format clé : MT-XXXXXXXX-XXXXXXXX20260330
  static final _pattern = RegExp(
    r'^MT-([A-Z0-9]{8})-([A-Z0-9]{8})(\d{8})$',
  );

  static ValidationResult valider({
    required String cle,
    required String deviceId,
  }) {
    // 1. Vérifier format
    final match = _pattern.firstMatch(cle);
    if (match == null) {
      return ValidationResult.invalide('Format de clé invalide');
    }

    // 2. Extraire date depuis la clé
    final dateStr = match.group(3)!;
    DateTime dateFin;
    try {
      dateFin = DateTime(
        int.parse(dateStr.substring(0, 4)),
        int.parse(dateStr.substring(4, 6)),
        int.parse(dateStr.substring(6, 8)),
      );
    } catch (_) {
      return ValidationResult.invalide('Date invalide dans la clé');
    }

    // 3. Vérifier expiration
    if (DateTime.now().isAfter(dateFin)) {
      final expDepuis = DateTime.now().difference(dateFin).inDays;
      return ValidationResult.invalide(
        'Clé expirée depuis $expDepuis jours',
      );
    }

    // 4. Clé valide
    final jours = dateFin.difference(DateTime.now()).inDays;
    return ValidationResult.valide(dateFin, jours);
  }
}

class ValidationResult {
  final bool valide;
  final String message;
  final DateTime? dateFin;
  final int joursRestants;

  ValidationResult.valide(this.dateFin, this.joursRestants)
      : valide = true,
        message = 'Clé valide';

  ValidationResult.invalide(this.message)
      : valide = false,
        dateFin = null,
        joursRestants = 0;
}
