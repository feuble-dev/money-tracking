import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracking/core/sms/sms_matching_engine.dart';
import 'package:moneytracking/core/sms/sms_pattern_builder.dart';

Map<String, Object?> _legacyPattern({
  required String rawExample,
  String transactionType = 'deposit',
  String direction = 'in',
  double commission = 1.5,
}) =>
    {
      'transaction_type': transactionType,
      'ott_transaction_type_id': 'tt_$transactionType',
      'operator_transaction_type_id': 'ott_$transactionType',
      'type_label': transactionType == 'deposit' ? 'Dépôt' : 'Retrait',
      'direction': direction,
      'ott_commission_taux': commission,
      'raw_example': rawExample,
      'regex_generated': 'auto_detect',
      'tagged_zones_json': null,
    };

Map<String, Object?> _structuredPattern({
  required String rawExample,
  required List<TaggedZone> zones,
  required String code,
  required String label,
  String? directionOverride,
  String defaultDirection = 'in',
  double commission = 2.0,
}) {
  final regex = SmsPatternBuilder.buildRegex(rawExample, zones);
  return {
    'transaction_type': code,
    'ott_transaction_type_id': 'tt_$code',
    'operator_transaction_type_id': 'ott_$code',
    'type_label': label,
    'direction': directionOverride ?? defaultDirection,
    'ott_commission_taux': commission,
    'raw_example': rawExample,
    'regex_generated': regex,
    'tagged_zones_json': jsonEncode(zones.map((z) => z.toJson()).toList()),
  };
}

void main() {
  group('SmsMatchingEngine — patterns legacy (auto_detect)', () {
    test('matche quand toutes les phrases discriminantes sont présentes', () {
      final pattern = _legacyPattern(
        rawExample: 'Depot de 5000 FCFA recu de 70123456. Merci.',
      );
      const body = 'Depot de 8000 FCFA recu de 78999999. Merci.';

      final result = SmsMatchingEngine.match(body, [pattern]);

      expect(result, isNotNull);
      expect(result!.transactionTypeCode, 'deposit');
      expect(result.direction, 'in');
      expect(result.extractedFields['montant'], isNotNull);
    });

    test('ne matche pas si une partie des phrases discriminantes manque '
        '(comportement strict retenu — ex-règle de l\'import historique)', () {
      final pattern = _legacyPattern(
        rawExample: 'Vous avez recu un retrait de 5000 FCFA au guichet.',
      );
      // Contient "retrait de" mais pas "vous avez recu" tel quel dans ce SMS.
      const body = 'Confirmation: retrait de 8000 FCFA effectue ce jour.';

      final result = SmsMatchingEngine.match(body, [pattern]);

      expect(result, isNull);
    });

    test('ignore un SMS sans rapport (ni phrase ni montant pertinent)', () {
      final pattern = _legacyPattern(
        rawExample: 'Depot de 5000 FCFA recu de 70123456. Merci.',
      );
      const body = 'Votre solde est disponible, rechargez des maintenant.';

      final result = SmsMatchingEngine.match(body, [pattern]);

      expect(result, isNull);
    });
  });

  group('SmsMatchingEngine — patterns structurés (catalogue / tagging)', () {
    test('matche via la regex compilée et extrait le montant', () {
      const rawExample = 'Depot de 5000 FCFA recu de 70123456. Ref: TXN1.';
      final zones = [
        TaggedZone(start: 9, end: 13, fieldName: 'montant', value: '5000'),
        TaggedZone(
            start: 27, end: 35, fieldName: 'numero_client', value: '70123456'),
      ];
      final pattern = _structuredPattern(
        rawExample: rawExample,
        zones: zones,
        code: 'deposit',
        label: 'Dépôt',
      );
      // Seules les zones taguées (montant, numero_client) varient — le
      // reste du texte n'a pas été tagué donc reste littéral dans la regex.
      const body = 'Depot de 7500 FCFA recu de 78111222. Ref: TXN1.';

      final result = SmsMatchingEngine.match(body, [pattern]);

      expect(result, isNotNull);
      expect(result!.extractedFields['montant'], '7500');
      expect(result.extractedFields['numero_client'], '78111222');
    });

    test(
        'D1 — le même type logique (Transfert) résout un sens différent '
        'selon le pattern qui matche (reçu=in vs envoyé=out)', () {
      const receivedExample = 'Vous avez recu un transfert de 3000 FCFA de 78000000.';
      final receivedZones = [
        TaggedZone(start: 31, end: 35, fieldName: 'montant', value: '3000'),
      ];
      final receivedPattern = _structuredPattern(
        rawExample: receivedExample,
        zones: receivedZones,
        code: 'transfert',
        label: 'Transfert',
        defaultDirection: 'in',
      );

      const sentExample = 'Vous avez envoye un transfert de 2000 FCFA a 78000000.';
      final sentZones = [
        TaggedZone(start: 33, end: 37, fieldName: 'montant', value: '2000'),
      ];
      final sentPattern = _structuredPattern(
        rawExample: sentExample,
        zones: sentZones,
        code: 'transfert',
        label: 'Transfert',
        defaultDirection: 'in',
        directionOverride: 'out',
      );

      final patterns = [receivedPattern, sentPattern];

      // Seul le montant (zone taguée) varie — le numéro n'a pas été tagué
      // dans ce test et reste donc littéral dans la regex générée.
      final receivedResult = SmsMatchingEngine.match(
        'Vous avez recu un transfert de 9000 FCFA de 78000000.',
        patterns,
      );
      expect(receivedResult, isNotNull);
      expect(receivedResult!.direction, 'in');
      expect(receivedResult.transactionTypeCode, 'transfert');

      final sentResult = SmsMatchingEngine.match(
        'Vous avez envoye un transfert de 1500 FCFA a 78000000.',
        patterns,
      );
      expect(sentResult, isNotNull);
      expect(sentResult!.direction, 'out');
      expect(sentResult.transactionTypeCode, 'transfert');
    });

    test('priorité aux patterns structurés sur les patterns legacy', () {
      final legacy = _legacyPattern(
        rawExample: 'Depot de 5000 FCFA recu de 70123456. Merci beaucoup.',
        commission: 9.9,
      );
      const rawExample = 'Depot de 5000 FCFA recu de 70123456. Merci beaucoup.';
      final zones = [
        TaggedZone(start: 9, end: 13, fieldName: 'montant', value: '5000'),
      ];
      final structured = _structuredPattern(
        rawExample: rawExample,
        zones: zones,
        code: 'deposit',
        label: 'Dépôt',
        commission: 1.0,
      );

      const body = 'Depot de 5000 FCFA recu de 70123456. Merci beaucoup.';
      final result = SmsMatchingEngine.match(body, [legacy, structured]);

      expect(result, isNotNull);
      // Le pattern structuré (commission 1.0) doit primer sur le legacy (9.9).
      expect(result!.commissionTaux, 1.0);
    });
  });

  test('retourne null si aucun pattern ne matche', () {
    final pattern = _legacyPattern(rawExample: 'Depot de 5000 FCFA recu de 70123456.');
    final result = SmsMatchingEngine.match('SMS totalement hors sujet.', [pattern]);
    expect(result, isNull);
  });

  group('SmsMatchingEngine — repli flou (confiance)', () {
    // Mots-clés distincts (pas de sous-chaîne accidentelle entre eux, hormis
    // "eta"/"theta" — volontaire, testé) pour rendre le calcul de score
    // déterministe : le montant reste toujours suivi de "FCFA" (nécessaire
    // pour que SmsFieldExtractor.extractAll, utilisé en repli, l'extraie).
    const rawExample =
        'ALPHA BETA 5000 FCFA GAMMA DELTA EPSILON ZETA ETA THETA IOTA KAPPA LAMBDA';
    final zones = [
      TaggedZone(start: 11, end: 15, fieldName: 'montant', value: '5000'),
    ];
    final pattern = _structuredPattern(
      rawExample: rawExample,
      zones: zones,
      code: 'retrait',
      label: 'Retrait',
      defaultDirection: 'out',
    );

    test('un seul mot manquant hors zone taguée -> confiance haute, '
        'création directe (needsConfirmation == false)', () {
      const body =
          'ALPHA BETA 7000 FCFA GAMMA DELTA EPSILON ZETA THETA IOTA KAPPA LAMBDA';

      final result = SmsMatchingEngine.match(body, [pattern]);

      expect(result, isNotNull);
      expect(result!.confidence, greaterThanOrEqualTo(SmsMatchingEngine.autoCreateMin));
      expect(result.needsConfirmation, isFalse);
      expect(result.extractedFields['montant'], '7000');
    });

    test('plusieurs mots manquants -> confiance moyenne, nécessite '
        'confirmation (needsConfirmation == true)', () {
      const body = 'ALPHA BETA 7000 FCFA ZETA ETA THETA IOTA KAPPA LAMBDA';

      final result = SmsMatchingEngine.match(body, [pattern]);

      expect(result, isNotNull);
      expect(result!.confidence, greaterThanOrEqualTo(SmsMatchingEngine.minConfidence));
      expect(result.confidence, lessThan(SmsMatchingEngine.autoCreateMin));
      expect(result.needsConfirmation, isTrue);
    });

    test('quasi rien en commun -> sous le seuil, ignoré (null)', () {
      const body = 'ALPHA BETA 7000 FCFA';

      final result = SmsMatchingEngine.match(body, [pattern]);

      expect(result, isNull);
    });
  });
}
