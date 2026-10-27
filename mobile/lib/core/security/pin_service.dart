import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service de gestion du code PIN.
///
/// Le PIN est stocké **dérivé** (PBKDF2-HMAC-SHA256, sel aléatoire de 16
/// octets, [_iterations] itérations) au format
/// `pbkdf2$<iter>$<selB64>$<hashB64>`. Un PIN a une entropie faible par
/// nature (4–6 chiffres) : la vraie protection reste le stockage sécurisé
/// (Keystore Android via `flutter_secure_storage`) ; la dérivation ne fait
/// que ralentir une attaque hors-ligne si ce stockage fuitait — bien mieux
/// qu'un simple SHA-256 non salé.
///
/// **Migration transparente** : les installs antérieures ont un hash
/// SHA-256 brut (64 hexa, sans `$`). À la première vérification réussie, le
/// PIN est réécrit au nouveau format — aucune action utilisateur.
class PinService {
  static const _pinKey = 'moneytracking_pin_hash';
  static const _pinSetKey = 'moneytracking_pin_set';
  static const _failCountKey = 'moneytracking_pin_fail_count';
  static const _lockUntilKey = 'moneytracking_pin_lock_until';

  /// Essais libres avant le premier blocage. Sans limite, 10 000 PIN de 4
  /// chiffres se testent en quelques minutes avec le téléphone en main.
  static const freeAttempts = 5;

  /// Blocage après [failures] échecs consécutifs : 30 s au 5ᵉ, puis doublé
  /// à chaque nouvel échec, plafonné à 15 min.
  static Duration lockoutFor(int failures) {
    if (failures < freeAttempts) return Duration.zero;
    final steps = (failures - freeAttempts).clamp(0, 5);
    final seconds = (30 * (1 << steps)).clamp(30, 900);
    return Duration(seconds: seconds);
  }
  // Un PIN de 4–6 chiffres a trop peu d'entropie pour qu'un nombre élevé
  // d'itérations change la donne face à une attaque hors-ligne ; on vise
  // surtout un déverrouillage instantané sur les téléphones d'entrée de
  // gamme courants au Burkina Faso.
  static const _iterations = 20000;

  final FlutterSecureStorage _storage;

  PinService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  // --- Dérivation ---------------------------------------------------------

  List<int> _pbkdf2(String pin, List<int> salt, int iterations) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    // Un seul bloc suffit (dkLen = 32 = taille de sortie SHA-256).
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final result = List<int>.from(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return result;
  }

  String _encode(String pin, {List<int>? salt, int? iterations}) {
    final s = salt ?? _randomSalt();
    final iter = iterations ?? _iterations;
    final hash = _pbkdf2(pin, s, iter);
    return 'pbkdf2\$$iter\$${base64.encode(s)}\$${base64.encode(hash)}';
  }

  List<int> _randomSalt() {
    final rnd = Random.secure();
    return List<int>.generate(16, (_) => rnd.nextInt(256));
  }

  /// Comparaison à temps constant (évite un oracle temporel).
  bool _constEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }

  String _legacySha256(String pin) =>
      sha256.convert(utf8.encode(pin)).toString();

  // --- API --------------------------------------------------------------

  Future<bool> isPinSet() async {
    final value = await _storage.read(key: _pinSetKey);
    return value == 'true';
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: _encode(pin));
    await _storage.write(key: _pinSetKey, value: 'true');
  }

  /// Temps restant avant de pouvoir retenter, [Duration.zero] si libre.
  /// Persisté : redémarrer l'app ne lève pas le blocage.
  Future<Duration> lockRemaining() async {
    final raw = await _storage.read(key: _lockUntilKey);
    final until = raw == null ? null : DateTime.tryParse(raw);
    if (until == null) return Duration.zero;
    final left = until.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Vérifie le PIN en tenant le compte des échecs. Pendant un blocage,
  /// renvoie `false` sans même comparer.
  Future<bool> verifyPin(String pin) async {
    if (await lockRemaining() > Duration.zero) return false;
    final ok = await _checkPin(pin);
    if (ok) {
      await _storage.delete(key: _failCountKey);
      await _storage.delete(key: _lockUntilKey);
    } else {
      final count =
          (int.tryParse(await _storage.read(key: _failCountKey) ?? '') ?? 0) + 1;
      await _storage.write(key: _failCountKey, value: '$count');
      final lock = lockoutFor(count);
      if (lock > Duration.zero) {
        await _storage.write(
            key: _lockUntilKey,
            value: DateTime.now().add(lock).toIso8601String());
      }
    }
    return ok;
  }

  Future<bool> _checkPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    if (stored == null || stored.isEmpty) return false;

    if (stored.startsWith('pbkdf2\$')) {
      final parts = stored.split('\$');
      if (parts.length != 4) return false;
      final iter = int.tryParse(parts[1]) ?? _iterations;
      final salt = base64.decode(parts[2]);
      final expected = base64.decode(parts[3]);
      return _constEquals(_pbkdf2(pin, salt, iter), expected);
    }

    // Format hérité : SHA-256 brut. On vérifie puis on ré-encode.
    if (_legacySha256(pin) == stored) {
      try {
        await setPin(pin);
      } catch (e) {
        debugPrint('[PinService] ré-encodage PBKDF2 échoué: $e');
      }
      return true;
    }
    return false;
  }

  Future<void> resetPin() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _pinSetKey);
    await _storage.delete(key: _failCountKey);
    await _storage.delete(key: _lockUntilKey);
  }
}
