import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Mot de passe incorrect, ou fichier modifié après coup.
class BackupWrongPassword implements Exception {
  const BackupWrongPassword();
}

/// Le fichier n'est pas une sauvegarde MoneyTracking.
class BackupFormatException implements Exception {
  final String message;
  const BackupFormatException(this.message);
  @override
  String toString() => message;
}

/// Nature d'un fichier de sauvegarde, d'après ses premiers octets.
enum BackupKind { encrypted, legacyPlain, unknown }

/// Chiffrement des sauvegardes `.mmtbak` (format 2).
///
/// Avant, une sauvegarde était une copie brute de la base SQLite : toutes
/// les transactions et tous les clients en clair, partagés via WhatsApp ou
/// Drive. Désormais :
///
/// `MMTBAK2\0` (8) · itérations PBKDF2 (u32) · sel (16) · nonce (12) ·
/// base chiffrée AES-256-GCM + tag (16).
///
/// La clé dérive du mot de passe choisi à la sauvegarde (PBKDF2-HMAC-SHA256)
/// ; GCM authentifie le contenu, donc un mauvais mot de passe ou un fichier
/// altéré sont détectés ([BackupWrongPassword]) au lieu de produire une
/// base corrompue. Sans le mot de passe, la sauvegarde est irrécupérable.
///
/// Fonctions pures et coûteuses (PBKDF2) : à appeler hors du thread UI
/// (`Isolate.run`, voir BackupService).
class BackupCrypto {
  BackupCrypto._();

  static final List<int> _magic = ascii.encode('MMTBAK2\u0000');
  static const _sqliteHeader = 'SQLite format 3\u0000';
  static const defaultIterations = 100000;
  static const _headerLength = 8 + 4 + 16 + 12;

  static final _aes = AesGcm.with256bits();

  static BackupKind detect(List<int> firstBytes) {
    if (firstBytes.length >= 8 && _startsWith(firstBytes, _magic)) {
      return BackupKind.encrypted;
    }
    if (firstBytes.length >= 16 &&
        String.fromCharCodes(firstBytes.sublist(0, 16)) == _sqliteHeader) {
      return BackupKind.legacyPlain;
    }
    return BackupKind.unknown;
  }

  static bool isSqlite(List<int> bytes) =>
      bytes.length >= 16 &&
      String.fromCharCodes(bytes.sublist(0, 16)) == _sqliteHeader;

  static Future<SecretKey> _deriveKey(
      String password, List<int> salt, int iterations) {
    return Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    ).deriveKeyFromPassword(password: password, nonce: salt);
  }

  static Future<Uint8List> encrypt(Uint8List plain, String password,
      {int iterations = defaultIterations}) async {
    final salt = SecretKeyData.random(length: 16).bytes;
    final key = await _deriveKey(password, salt, iterations);
    final box = await _aes.encrypt(plain, secretKey: key);

    final out = BytesBuilder(copy: false)
      ..add(_magic)
      ..add((ByteData(4)..setUint32(0, iterations)).buffer.asUint8List())
      ..add(salt)
      ..add(box.nonce)
      ..add(box.cipherText)
      ..add(box.mac.bytes);
    return out.toBytes();
  }

  static Future<Uint8List> decrypt(Uint8List data, String password) async {
    if (detect(data) != BackupKind.encrypted ||
        data.length < _headerLength + 16) {
      throw const BackupFormatException(
          "Ce fichier n'est pas une sauvegarde MoneyTracking chiffrée");
    }
    final iterations = ByteData.sublistView(data, 8, 12).getUint32(0);
    if (iterations < 1000 || iterations > 10000000) {
      throw const BackupFormatException('Sauvegarde endommagée');
    }
    final salt = data.sublist(12, 28);
    final nonce = data.sublist(28, 40);
    final cipherText = data.sublist(40, data.length - 16);
    final mac = Mac(data.sublist(data.length - 16));

    final key = await _deriveKey(password, salt, iterations);
    try {
      final plain = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: mac),
        secretKey: key,
      );
      return Uint8List.fromList(plain);
    } on SecretBoxAuthenticationError {
      throw const BackupWrongPassword();
    }
  }

  static bool _startsWith(List<int> data, List<int> prefix) {
    for (var i = 0; i < prefix.length; i++) {
      if (data[i] != prefix[i]) return false;
    }
    return true;
  }
}
