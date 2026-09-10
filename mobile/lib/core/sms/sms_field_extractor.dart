import 'package:flutter/foundation.dart';

/// Extracteur de champs SMS par patterns indépendants
/// Chaque champ est extrait séparément — plus besoin de regex monolithique
class SmsFieldExtractor {
  /// Patterns prédéfinis pour extraire chaque champ
  /// Chaque pattern a un groupe de capture (group 1) pour la valeur
  static const Map<String, List<String>> fieldPatterns = {
    // Montant : cherche un nombre suivi de FCFA. Chaque alternative est
    // ancrée par `(?<!\d)` (pas précédé d'un chiffre) — sans ça, un nombre
    // contigu de 4+ chiffres sans séparateur (ex: "7000 FCFA", fréquent
    // pour les montants ronds) pouvait matcher en plein milieu du nombre
    // (le `\d{1,3}` des motifs à séparateurs trouvait "000" au lieu de
    // "7000", parce que rien n'empêchait de démarrer après le premier "7").
    'montant': [
      r'(?<!\d)(\d{1,3}(?:,\d{3})*(?:\.\d{1,2})?)\s*FCFA',
      r'(?<!\d)(\d{1,3}(?:\.\d{3})*(?:,\d{1,2})?)\s*FCFA',
      r'(?<!\d)(\d+(?:[\s.]\d{3})*)\s*FCFA',
      r'(?<!\d)(\d+)\s*FCFA',
    ],

    // Numéro client : 8 chiffres après un mot-clé
    'numero_client': [
      r'(?:du|au\s+numero|de)\s+(\d{8})',
      r'(?:du|au\s+numero|de)\s+(\d{10})',
      r',(\d{8}),',       // format: numero,nom
      r'\s(\d{8}),',       // espace puis 8 chiffres puis virgule
    ],

    // ID transaction : format PP260323.1749.60705295 ou similaire
    'operator_transaction_id': [
      r'(?:ID\s*Trans\s*:|Trans\s*ID\s*:)\s*([A-Z0-9]+(?:\.[A-Z0-9]+)*)',
      r'(?:Ref|Reference)\s*:\s*([A-Z0-9]+(?:[\.\-][A-Z0-9]+)*)',
    ],

    // Solde : nombre après "solde est de" ou "solde de votre compte"
    'solde': [
      r'solde(?:\s+de\s+votre\s+compte)?\s+est\s+de\s+(\d[\d,]*(?:\.\d{1,2})?)',
      r'solde\s*:\s*(\d[\d,]*(?:\.\d{1,2})?)',
      r'solde\s+est\s+de\s+(\d[\d\s.]*(?:[.,]\d{1,2})?)',
    ],

    // Nom client : texte après le numéro (après la virgule)
    'nom_client': [
      r'\d{8},([A-Za-zÀ-ÿ\s]+?)\.', // 8 chiffres, puis nom jusqu'au point
      r'\d{8},([A-Za-zÀ-ÿ\s]+)',     // 8 chiffres, puis nom
    ],
  };

  /// Détecte le type de transaction (dépôt ou retrait)
  static String? detectTransactionType(String sms) {
    final lower = sms.toLowerCase();
    if (lower.contains('transfere') || lower.contains('envoye') || lower.contains('depot')) {
      return 'deposit';
    }
    if (lower.contains('recu') || lower.contains('retrait') || lower.contains('received')) {
      return 'withdrawal';
    }
    return null;
  }

  /// Extrait un champ en testant tous les patterns possibles
  static String? extractField(String sms, String fieldName) {
    final patterns = fieldPatterns[fieldName];
    if (patterns == null) return null;

    for (final pattern in patterns) {
      try {
        final regex = RegExp(pattern, caseSensitive: false);
        final match = regex.firstMatch(sms);
        if (match != null && match.group(1) != null) {
          return match.group(1)!.trim();
        }
      } catch (_) {}
    }
    return null;
  }

  /// Extrait tous les champs possibles d'un SMS
  static Map<String, String> extractAll(String sms) {
    final result = <String, String>{};
    for (final fieldName in fieldPatterns.keys) {
      final value = extractField(sms, fieldName);
      if (value != null && value.isNotEmpty) {
        result[fieldName] = value;
      }
    }
    return result;
  }

  /// Extrait les champs avec des patterns personnalisés (depuis la config)
  static Map<String, String> extractWithCustomPatterns(
      String sms, Map<String, String> customPatterns) {
    final result = <String, String>{};
    customPatterns.forEach((field, pattern) {
      try {
        final regex = RegExp(pattern, caseSensitive: false);
        final match = regex.firstMatch(sms);
        if (match != null && match.group(1) != null) {
          result[field] = match.group(1)!.trim();
        }
      } catch (e) {
        debugPrint('[SmsExtractor] Pattern error for $field: $e');
      }
    });
    return result;
  }

  /// Convertit un montant capturé en double, en devinant lequel de ',' ou
  /// '.' est le séparateur décimal plutôt qu'un séparateur de milliers.
  ///
  /// Règle : le DERNIER ',' ou '.' du texte est décimal seulement s'il est
  /// suivi d'exactement 1 ou 2 chiffres jusqu'à la fin — cas des centimes
  /// FCFA (",00" quasi systématique dans les vrais SMS Moov/Coris/Orange).
  /// Sinon (3 chiffres après, ex: "1,010"), c'est un groupement de
  /// milliers classique et tout est supprimé.
  ///
  /// Corrige un bug réel : l'ancienne version traitait toute virgule SEULE
  /// comme un séparateur de milliers, donc "100,00" (cent FCFA exactement,
  /// convention Moov Money) devenait 10000.0 — cent fois trop. Gère aussi
  /// les formats mixtes espace-milliers + virgule-décimale ("1 521,00").
  ///
  /// "1,010.00" → 1010.0 | "5 000" → 5000.0 | "100,00" → 100.0 |
  /// "1 521,00" → 1521.0 | "1,025" → 1025.0 (pas de partie décimale)
  static double? parseMontant(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final s = raw.trim().replaceAll(RegExp(r'[\s ]'), '');
    if (s.isEmpty) return null;

    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    final decimalIdx = lastComma > lastDot ? lastComma : lastDot;

    if (decimalIdx == -1) {
      return double.tryParse(s);
    }

    final afterDecimal = s.substring(decimalIdx + 1);
    final isDecimalSeparator =
        afterDecimal.length <= 2 && RegExp(r'^\d+$').hasMatch(afterDecimal);

    if (isDecimalSeparator) {
      final integerPart = s.substring(0, decimalIdx).replaceAll(RegExp(r'[.,]'), '');
      return double.tryParse('$integerPart.$afterDecimal');
    }
    return double.tryParse(s.replaceAll(RegExp(r'[.,]'), ''));
  }

  /// Nettoie un numéro de téléphone
  static String? cleanPhone(String? raw) {
    if (raw == null) return null;
    return raw.replaceAll(RegExp(r'[^\d+]'), '');
  }
}
