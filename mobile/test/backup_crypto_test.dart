import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:moneytracking/features/backup/data/backup_crypto.dart';

void main() {
  // Fausse base SQLite : seul l'en-tête compte pour ces tests.
  final plain = Uint8List.fromList([
    ...ascii.encode('SQLite format 3\u0000'),
    ...List.generate(4096, (i) => i % 251),
  ]);
  const fast = 2000; // itérations réduites pour la vitesse des tests

  test('chiffre puis déchiffre à l\'identique', () async {
    final enc = await BackupCrypto.encrypt(plain, 'mot-de-passe', iterations: fast);
    expect(BackupCrypto.detect(enc), BackupKind.encrypted);
    // Plus aucune trace de la base en clair.
    expect(BackupCrypto.isSqlite(enc), isFalse);
    final dec = await BackupCrypto.decrypt(enc, 'mot-de-passe');
    expect(dec, plain);
  });

  test('mauvais mot de passe détecté', () async {
    final enc = await BackupCrypto.encrypt(plain, 'bon', iterations: fast);
    expect(() => BackupCrypto.decrypt(enc, 'mauvais'),
        throwsA(isA<BackupWrongPassword>()));
  });

  test('fichier altéré détecté (pas de base corrompue restaurée)', () async {
    final enc = await BackupCrypto.encrypt(plain, 'pwd', iterations: fast);
    enc[enc.length - 100] ^= 0xFF;
    expect(() => BackupCrypto.decrypt(enc, 'pwd'),
        throwsA(isA<BackupWrongPassword>()));
  });

  test('deux sauvegardes du même contenu diffèrent (sel et nonce)', () async {
    final a = await BackupCrypto.encrypt(plain, 'pwd', iterations: fast);
    final b = await BackupCrypto.encrypt(plain, 'pwd', iterations: fast);
    expect(a, isNot(b));
  });

  test('ancienne sauvegarde en clair et fichier inconnu reconnus', () {
    expect(BackupCrypto.detect(plain), BackupKind.legacyPlain);
    expect(BackupCrypto.detect(ascii.encode('nimporte quoi ici...')),
        BackupKind.unknown);
  });
}
