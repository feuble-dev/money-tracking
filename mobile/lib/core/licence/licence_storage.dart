import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum LicenceStatut {
  nonActivee,
  essaiActif,
  active,
  expireBientot,
  expiree,

  /// Compte Particulier : MoneyTracking est gratuit, sans échéance.
  gratuit;

  /// Le compte peut-il créer/modifier des données (transactions, clients…) ?
  bool get permetEcriture =>
      this == active || this == essaiActif || this == expireBientot || this == gratuit;
}

class LicenceStorage {
  static const _storage = FlutterSecureStorage();
  static const _keyLicence = 'mt_licence';
  static const _keyTelephone = 'mt_telephone';

  static Future<void> sauvegarder(Map<String, dynamic> data) async {
    await _storage.write(
      key: _keyLicence,
      value: jsonEncode(data),
    );
  }

  static Future<Map<String, dynamic>?> lire() async {
    final raw = await _storage.read(key: _keyLicence);
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  /// Clé SharedPreferences du type de compte (OnboardingStatusService) — lue
  /// directement : ce fichier doit rester utilisable depuis l'isolate SMS
  /// headless, sans base de données.
  static const _kAccountType = 'account_type';

  static Future<bool> estParticulier() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccountType) == 'particulier';
  }

  static Future<LicenceStatut> verifierLocalement() async {
    if (await estParticulier()) return LicenceStatut.gratuit;
    final data = await lire();
    if (data == null) return LicenceStatut.nonActivee;

    final dateFinStr = data['date_fin'] as String?;
    if (dateFinStr == null) return LicenceStatut.nonActivee;

    final dateFin = DateTime.parse(dateFinStr);
    final jours = dateFin.difference(DateTime.now()).inDays;
    final statut = data['statut'] as String?;

    if (DateTime.now().isAfter(dateFin)) {
      return LicenceStatut.expiree;
    }
    if (statut == 'essai') return LicenceStatut.essaiActif;
    if (jours <= 7) return LicenceStatut.expireBientot;
    return LicenceStatut.active;
  }

  /// Jours avant expiration ; très grand pour un compte gratuit (aucune
  /// bannière « licence expire » ne doit s'afficher).
  static Future<int> getJoursRestants() async {
    if (await estParticulier()) return 1 << 30;
    final data = await lire();
    if (data == null) return 0;
    final dateFinStr = data['date_fin'] as String?;
    if (dateFinStr == null) return 0;
    final dateFin = DateTime.parse(dateFinStr);
    return dateFin.difference(DateTime.now()).inDays.clamp(0, 9999);
  }

  static Future<String?> getDateFin() async {
    final data = await lire();
    if (data == null) return null;
    return data['date_fin'] as String?;
  }

  static Future<String?> getCode() async {
    final data = await lire();
    if (data == null) return null;
    return data['code'] as String?;
  }

  static Future<void> saveTelephone(String tel) async {
    await _storage.write(key: _keyTelephone, value: tel);
  }

  static Future<String?> getTelephone() async {
    return _storage.read(key: _keyTelephone);
  }

  static Future<void> supprimer() async {
    await _storage.delete(key: _keyLicence);
  }
}
