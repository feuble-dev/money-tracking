import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Zone taguée dans un SMS exemple
class TaggedZone {
  final int start;
  final int end;
  final String fieldName;
  final String value;

  TaggedZone({
    required this.start,
    required this.end,
    required this.fieldName,
    required this.value,
  });

  Map<String, dynamic> toJson() => {
        'start': start,
        'end': end,
        'fieldName': fieldName,
        'value': value,
      };

  factory TaggedZone.fromJson(Map<String, dynamic> json) => TaggedZone(
        start: json['start'] as int,
        end: json['end'] as int,
        fieldName: json['fieldName'] as String,
        value: json['value'] as String,
      );
}

/// Constructeur de patterns SMS dynamiques
class SmsPatternBuilder {
  /// Caractères considérés comme des espaces (incluant Unicode)
  static bool _isWhitespace(String char) {
    if (char.isEmpty) return false;
    final code = char.codeUnitAt(0);
    return char == ' ' ||
        char == '\t' ||
        char == '\n' ||
        char == '\r' ||
        code == 0x00A0 || // non-breaking space
        code == 0x200B || // zero-width space
        code == 0x200C || // zero-width non-joiner
        code == 0x200D || // zero-width joiner
        code == 0xFEFF || // BOM / zero-width no-break space
        code == 0x2007 || // figure space
        code == 0x2008 || // punctuation space
        code == 0x2009 || // thin space
        code == 0x200A || // hair space
        code == 0x202F || // narrow no-break space
        code == 0x205F;   // medium mathematical space
  }

  /// Nettoie un SMS des caractères invisibles Unicode
  static String cleanSms(String sms) {
    return sms
        .replaceAll(RegExp(r'[\u00A0\u200B\u200C\u200D\uFEFF\u202F\u2007-\u200A\u205F]'), ' ')
        .replaceAll(RegExp(r'\r\n'), '\n')
        .replaceAll('\r', '\n');
  }

  /// Génère une regex à partir d'un SMS brut et de zones taguées
  static String buildRegex(String rawSms, List<TaggedZone> zones) {
    if (zones.isEmpty) return RegExp.escape(rawSms);

    final sortedZones = List<TaggedZone>.from(zones)
      ..sort((a, b) => a.start.compareTo(b.start));

    final buffer = StringBuffer();
    int currentPos = 0;

    for (final zone in sortedZones) {
      if (zone.start > currentPos) {
        final textBetween = rawSms.substring(currentPos, zone.start);
        buffer.write(_escapeWithWhitespaceFlexibility(textBetween));
      }
      buffer.write(_buildCaptureGroup(zone));
      currentPos = zone.end;
    }

    if (currentPos < rawSms.length) {
      final remaining = rawSms.substring(currentPos);
      buffer.write(_escapeWithWhitespaceFlexibility(remaining));
    }

    final regex = buffer.toString();

    // Validation : la regex DOIT matcher le SMS exemple
    try {
      final r = RegExp(regex, multiLine: true, unicode: true);
      if (!r.hasMatch(rawSms)) {
        debugPrint('[SmsPattern] ALERTE: regex ne matche pas le SMS exemple !');
        debugPrint('[SmsPattern] Regex: $regex');
      }
    } catch (e) {
      debugPrint('[SmsPattern] Regex invalide: $e');
    }

    return regex;
  }

  /// Construit le groupe de capture regex pour un champ
  /// IMPORTANT: les patterns NE doivent PAS contenir \s pour éviter
  /// de dévorer les espaces qui servent de séparateur entre les champs
  static String _buildCaptureGroup(TaggedZone zone) {
    switch (zone.fieldName) {
      case 'montant':
        // Commence par un chiffre, puis chiffres/virgules/points
        // Gère: 1000, 1,010.00, 1.250.000, 5 000 (espace milliers)
        return r'(?<montant>\d[\d.,]*(?:[\u00A0 ]\d{3})*)';
      case 'numero_client':
        // Numéro de téléphone: chiffres contigus, éventuellement +
        return r'(?<numero_client>\+?\d[\d]*)';
      case 'operator_transaction_id':
        // ID opérateur: alphanum, points, tirets (ex: PP260323.1749.60705295)
        return r'(?<operator_transaction_id>[\w.\-]+)';
      case 'operator_reference':
        return r'(?<operator_reference>[\w.\-]+)';
      case 'solde':
        // Même logique que montant
        return r'(?<solde>\d[\d.,]*(?:[\u00A0 ]\d{3})*)';
      case 'nom_client':
        // Nom: lettres, espaces, accents, apostrophes, tirets
        return r"(?<nom_client>[A-Za-zÀ-ÿ][\w\sÀ-ÿ'\-]*)";
      default:
        return '(.+?)';
    }
  }

  /// Échappe les caractères regex ET ajoute de la flexibilité sur les espaces
  /// Tous les types d'espaces (y compris Unicode) sont remplacés par \s+
  static String _escapeWithWhitespaceFlexibility(String text) {
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      if (_isWhitespace(char)) {
        // Remplacer tous les espaces consécutifs par un pattern flexible
        if (buffer.isEmpty || !buffer.toString().endsWith(r'[\s\u00A0]+')) {
          buffer.write(r'[\s\u00A0]+');
        }
        // Sauter les espaces consécutifs
        while (i + 1 < text.length && _isWhitespace(text[i + 1])) {
          i++;
        }
      } else {
        buffer.write(RegExp.escape(char));
      }
    }
    return buffer.toString();
  }

  /// Parse un SMS avec une regex et retourne les valeurs extraites
  static Map<String, String>? parseSms(String sms, String regex) {
    try {
      // Nettoyer le SMS avant le matching
      final cleanedSms = cleanSms(sms);
      final regExp = RegExp(regex, multiLine: true, unicode: true);

      // Essayer d'abord sur le SMS brut, puis sur le nettoyé
      var match = regExp.firstMatch(sms);
      match ??= regExp.firstMatch(cleanedSms);

      if (match == null) {
        debugPrint('[SmsPattern] NO MATCH');
        debugPrint('[SmsPattern] Regex: $regex');
        debugPrint('[SmsPattern] SMS (${sms.length} chars): $sms');
        return null;
      }

      final result = <String, String>{};
      const groupNames = [
        'montant',
        'numero_client',
        'operator_transaction_id',
        'operator_reference',
        'solde',
        'nom_client',
      ];

      for (final name in groupNames) {
        try {
          final value = match.namedGroup(name);
          if (value != null) {
            result[name] = value.trim();
          }
        } catch (_) {}
      }

      if (result.isNotEmpty) {
        debugPrint('[SmsPattern] MATCH: $result');
      }

      return result.isEmpty ? null : result;
    } catch (e) {
      debugPrint('[SmsPattern] Error: $e');
      return null;
    }
  }

  static String zonesToJson(List<TaggedZone> zones) {
    return jsonEncode(zones.map((z) => z.toJson()).toList());
  }

  static List<TaggedZone> zonesFromJson(String json) {
    final list = jsonDecode(json) as List;
    return list.map((e) => TaggedZone.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// Nettoie un montant extrait et le convertit en double
  /// Gère les formats : 1,010.00 | 5 000 | 1.250.000 | 15000
  static double? cleanAmount(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var s = raw.trim();

    final hasComma = s.contains(',');
    final hasDot = s.contains('.');

    if (hasComma && hasDot) {
      // Format international : 1,010.00 (virgule=milliers, point=décimal)
      s = s.replaceAll(',', '');
    } else if (hasComma && !hasDot) {
      // Virgule seule = séparateur de milliers en FCFA : 1,010
      s = s.replaceAll(',', '');
    } else if (!hasComma && hasDot) {
      // Point seul : vérifier si c'est un séparateur de milliers
      // 1.250.000 → milliers (plusieurs points) vs 1010.50 → décimal (un point)
      final dotCount = '.'.allMatches(s).length;
      if (dotCount > 1) {
        // Plusieurs points = séparateurs de milliers
        s = s.replaceAll('.', '');
      }
      // Un seul point = décimal, on le garde
    }

    // Supprimer les espaces restants (séparateurs de milliers)
    s = s.replaceAll(RegExp(r'\s'), '');
    return double.tryParse(s);
  }

  /// Nettoie un numéro de téléphone extrait
  static String? cleanPhone(String? raw) {
    if (raw == null) return null;
    return raw.replaceAll(RegExp(r'[^\d+]'), '');
  }
}
