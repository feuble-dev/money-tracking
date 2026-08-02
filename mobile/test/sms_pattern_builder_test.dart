import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracking/core/sms/sms_field_extractor.dart';

void main() {
  group('SmsFieldExtractor', () {
    // === VRAIS SMS ORANGE MONEY BF ===

    const depotSms =
        'Cher client, vous avez transfere 1,010.00 FCFA au numero '
        '65832806,Pibone Jerome. Votre solde est de  2136.62 FCFA. '
        'ID Trans: PP260323.1749.60705295. Pour toute reclamation '
        'contactez par appel le 127 ou whatsapp 07000121. Orange Money BF';

    const retraitSms =
        'Vous avez recu 1,025.00 FCFA du 57347104,ABDOUL RACHID. '
        'Le solde de votre compte est de 1041.62 FCFA Trans ID: '
        'PP260325.1506.25700153. Flashez le QR CODE marchand avec '
        'Max it pour plus de facilite : https://onelink.to/nn64xw';

    // --- Détection de type ---

    test('detectTransactionType — dépôt', () {
      expect(SmsFieldExtractor.detectTransactionType(depotSms), 'deposit');
    });

    test('detectTransactionType — retrait', () {
      expect(SmsFieldExtractor.detectTransactionType(retraitSms), 'withdrawal');
    });

    test('detectTransactionType — inconnu', () {
      expect(SmsFieldExtractor.detectTransactionType('Bonjour'), isNull);
    });

    // --- Extraction montant ---

    test('extractField montant — dépôt', () {
      final montant = SmsFieldExtractor.extractField(depotSms, 'montant');
      expect(montant, isNotNull);
      expect(SmsFieldExtractor.parseMontant(montant), 1010.0);
    });

    test('extractField montant — retrait', () {
      final montant = SmsFieldExtractor.extractField(retraitSms, 'montant');
      expect(montant, isNotNull);
      expect(SmsFieldExtractor.parseMontant(montant), 1025.0);
    });

    // --- Extraction numéro client ---

    test('extractField numero_client — dépôt', () {
      final phone = SmsFieldExtractor.extractField(depotSms, 'numero_client');
      expect(phone, '65832806');
    });

    test('extractField numero_client — retrait', () {
      final phone = SmsFieldExtractor.extractField(retraitSms, 'numero_client');
      expect(phone, '57347104');
    });

    // --- Extraction ID transaction ---

    test('extractField operator_transaction_id — dépôt', () {
      final txId = SmsFieldExtractor.extractField(depotSms, 'operator_transaction_id');
      expect(txId, 'PP260323.1749.60705295');
    });

    test('extractField operator_transaction_id — retrait', () {
      final txId = SmsFieldExtractor.extractField(retraitSms, 'operator_transaction_id');
      expect(txId, 'PP260325.1506.25700153');
    });

    // --- Extraction solde ---

    test('extractField solde — dépôt', () {
      final solde = SmsFieldExtractor.extractField(depotSms, 'solde');
      expect(solde, isNotNull);
      expect(SmsFieldExtractor.parseMontant(solde), 2136.62);
    });

    test('extractField solde — retrait', () {
      final solde = SmsFieldExtractor.extractField(retraitSms, 'solde');
      expect(solde, isNotNull);
      expect(SmsFieldExtractor.parseMontant(solde), 1041.62);
    });

    // --- Extraction complète ---

    test('extractAll — dépôt Orange Money BF complet', () {
      final result = SmsFieldExtractor.extractAll(depotSms);
      expect(result['montant'], isNotNull);
      expect(result['numero_client'], '65832806');
      expect(result['operator_transaction_id'], 'PP260323.1749.60705295');
      expect(result['solde'], isNotNull);
      expect(SmsFieldExtractor.parseMontant(result['montant']), 1010.0);
    });

    test('extractAll — retrait Orange Money BF complet', () {
      final result = SmsFieldExtractor.extractAll(retraitSms);
      expect(result['montant'], isNotNull);
      expect(result['numero_client'], '57347104');
      expect(result['operator_transaction_id'], 'PP260325.1506.25700153');
      expect(result['solde'], isNotNull);
      expect(SmsFieldExtractor.parseMontant(result['montant']), 1025.0);
    });

    // --- SMS similaires (montants différents) ---

    test('extractAll — dépôt avec montants différents', () {
      const sms =
          'Cher client, vous avez transfere 5,000.00 FCFA au numero '
          '70123456,Kader Ouedraogo. Votre solde est de  15000.00 FCFA. '
          'ID Trans: PP260327.1200.12345678. Pour toute reclamation '
          'contactez par appel le 127 ou whatsapp 07000121. Orange Money BF';

      final result = SmsFieldExtractor.extractAll(sms);
      expect(result['numero_client'], '70123456');
      expect(SmsFieldExtractor.parseMontant(result['montant']), 5000.0);
      expect(result['operator_transaction_id'], 'PP260327.1200.12345678');
    });

    test('extractAll — retrait avec montants différents', () {
      const sms =
          'Vous avez recu 3,500.00 FCFA du 65000111,OUEDRAOGO AHMED. '
          'Le solde de votre compte est de 5500.00 FCFA Trans ID: '
          'PP260327.0900.99887766. Flashez le QR CODE marchand.';

      final result = SmsFieldExtractor.extractAll(sms);
      expect(result['numero_client'], '65000111');
      expect(SmsFieldExtractor.parseMontant(result['montant']), 3500.0);
    });

    // --- parseMontant ---

    test('parseMontant — tous les formats', () {
      expect(SmsFieldExtractor.parseMontant('5000'), 5000.0);
      expect(SmsFieldExtractor.parseMontant('5 000'), 5000.0);
      expect(SmsFieldExtractor.parseMontant('1,010.00'), 1010.0);
      expect(SmsFieldExtractor.parseMontant('5,000.00'), 5000.0);
      expect(SmsFieldExtractor.parseMontant('1,025'), 1025.0);
      expect(SmsFieldExtractor.parseMontant('2136.62'), 2136.62);
      expect(SmsFieldExtractor.parseMontant('1.250.000'), 1250000.0);
      expect(SmsFieldExtractor.parseMontant(null), isNull);
    });

    // --- cleanPhone ---

    test('cleanPhone', () {
      expect(SmsFieldExtractor.cleanPhone('70 12 34 56'), '70123456');
      expect(SmsFieldExtractor.cleanPhone('+22670123456'), '+22670123456');
      expect(SmsFieldExtractor.cleanPhone(null), isNull);
    });
  });
}
