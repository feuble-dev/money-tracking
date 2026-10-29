import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/api_config.dart';
import '../network/api_client.dart';

/// Contenu d'une clé de licence hors ligne `MT2-…` authentique.
class OfflineLicence {
  final int agenceId;
  final DateTime dateFin;
  final String statut; // 'active' | 'essai'
  const OfflineLicence(this.agenceId, this.dateFin, this.statut);
}

/// Vérification HORS LIGNE des clés signées Ed25519 émises par le backend
/// (miroir de `backend/licences/signature.py`). L'app ne détient que la clé
/// publique : elle peut vérifier une clé, jamais en fabriquer une.
///
/// Contenu signé (13 octets, big-endian) : agence_id (u32) · jours depuis
/// 2020-01-01 (u16) · 6 premiers octets de SHA-256(device_id) · statut (u8),
/// suivi de la signature (64 octets), le tout en base64url après `MT2-`.
class OfflineKey {
  OfflineKey._();

  static const prefix = 'MT2-';
  static const _contentLength = 13;
  static final _epoch = DateTime.utc(2020, 1, 1);

  static const _storage = FlutterSecureStorage();
  static const _kPublicKey = 'mt_licence_public_key';

  /// Repli compilé (facultatif) : `--dart-define=LICENCE_PUBLIC_KEY=…`.
  static const _buildPublicKey = String.fromEnvironment('LICENCE_PUBLIC_KEY');

  static bool looksLike(String key) => key.trim().startsWith(prefix);

  /// Récupère et mémorise la clé publique du serveur (silencieux hors ligne).
  /// Appelée au démarrage : la vérification hors ligne fonctionne ensuite
  /// sans réseau.
  static Future<void> refreshPublicKey() async {
    try {
      final res = await ApiClient.get('${ApiConfig.licence}/cle-publique/',
          timeout: const Duration(seconds: 8));
      final key = res.data['cle'];
      if (res.ok && key is String && key.isNotEmpty) {
        await _storage.write(key: _kPublicKey, value: key);
      }
    } catch (_) {}
  }

  static Future<String?> _publicKey() async {
    final stored = await _storage.read(key: _kPublicKey);
    if (stored != null && stored.isNotEmpty) return stored;
    return _buildPublicKey.isEmpty ? null : _buildPublicKey;
  }

  /// `null` si la clé est fausse, altérée, émise pour un autre appareil, ou
  /// si aucune clé publique n'est encore connue (jamais connecté).
  static Future<OfflineLicence?> verify(String key, String deviceId) async {
    final publicKey = await _publicKey();
    if (publicKey == null) return null;
    return verifyWith(key, deviceId, base64.decode(publicKey));
  }

  /// Vérification pure (testable) avec une clé publique donnée.
  static Future<OfflineLicence?> verifyWith(
      String key, String deviceId, List<int> publicKey) async {
    key = key.trim();
    if (!key.startsWith(prefix)) return null;
    Uint8List raw;
    try {
      raw = base64Url.decode(base64Url.normalize(key.substring(prefix.length)));
    } catch (_) {
      return null;
    }
    if (raw.length != _contentLength + 64) return null;
    final content = raw.sublist(0, _contentLength);
    final sig = raw.sublist(_contentLength);

    final valid = await Ed25519().verify(
      content,
      signature: Signature(sig,
          publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519)),
    );
    if (!valid) return null;

    final bytes = ByteData.sublistView(content);
    final agenceId = bytes.getUint32(0);
    final days = bytes.getUint16(4);
    final fingerprint = content.sublist(6, 12);
    final statusByte = bytes.getUint8(12);

    final expected =
        crypto.sha256.convert(utf8.encode(deviceId)).bytes.sublist(0, 6);
    for (var i = 0; i < 6; i++) {
      if (fingerprint[i] != expected[i]) return null;
    }
    final end = _epoch.add(Duration(days: days));
    return OfflineLicence(
      agenceId,
      DateTime(end.year, end.month, end.day),
      statusByte == 2 ? 'essai' : 'active',
    );
  }
}
