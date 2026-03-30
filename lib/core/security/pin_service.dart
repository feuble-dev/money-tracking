import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service de gestion du code PIN
class PinService {
  static const _pinKey = 'moneytracking_pin_hash';
  static const _pinSetKey = 'moneytracking_pin_set';
  final FlutterSecureStorage _storage;

  PinService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  /// Hash SHA-256 du PIN
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Vérifie si un PIN a été configuré
  Future<bool> isPinSet() async {
    final value = await _storage.read(key: _pinSetKey);
    return value == 'true';
  }

  /// Enregistre un nouveau PIN
  Future<void> setPin(String pin) async {
    final hash = _hashPin(pin);
    await _storage.write(key: _pinKey, value: hash);
    await _storage.write(key: _pinSetKey, value: 'true');
  }

  /// Vérifie le PIN saisi
  Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _pinKey);
    if (storedHash == null) return false;
    return _hashPin(pin) == storedHash;
  }

  /// Réinitialise le PIN
  Future<void> resetPin() async {
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _pinSetKey);
  }
}
