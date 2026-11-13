import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database_helper.dart';
import '../licence/licence_service.dart';
import '../licence/licence_storage.dart';
import '../network/api_client.dart';
import '../config/api_config.dart';

/// Résultat d'une demande de suppression : `null` = supprimé, sinon le
/// message à montrer.
typedef DeletionError = String?;

/// Suppression du compte depuis l'app (exigence Google Play).
///
/// 1. Le serveur efface le compte (`POST /api/licence/compte/supprimer/`,
///    mot de passe exigé quand le compte en a un).
/// 2. Seulement ensuite, tout ce que l'app garde sur le téléphone est
///    effacé : base SQLite, stockage sécurisé (PIN, licence, jeton
///    d'appareil), préférences, logos en cache. Au prochain lancement l'app
///    repart de l'accueil, comme fraîchement installée.
///
/// Si le serveur refuse ou n'est pas joignable, rien n'est effacé en local :
/// on ne veut pas d'un téléphone vidé avec un compte encore vivant.
class AccountDeletion {
  static Future<DeletionError> deleteAccount(String password) async {
    final telephone = await LicenceStorage.getTelephone();
    if (telephone == null || telephone.isEmpty) {
      // Aucun compte serveur connu sur ce téléphone : effacement local seul.
      await wipeLocal();
      return null;
    }
    try {
      final res = await ApiClient.post('${ApiConfig.licence}/compte/supprimer/', {
        'telephone': telephone,
        'device_id': await LicenceService.getDeviceId(),
        'password': password,
      });
      if (res.ok) {
        await wipeLocal();
        return null;
      }
      if (res.statusCode == 401 && res.data['code'] == 'mot_de_passe') {
        return 'Mot de passe incorrect.';
      }
      if (res.statusCode == 429) return 'Trop de tentatives. Réessayez dans une minute.';
      if (res.statusCode == 403) {
        return 'Seul un téléphone du titulaire du compte peut le supprimer.';
      }
      return res.error('La suppression a échoué. Réessayez plus tard.');
    } catch (_) {
      return 'Pas de connexion Internet. Connectez-vous puis réessayez.';
    }
  }

  /// Efface toutes les données locales de l'app.
  static Future<void> wipeLocal() async {
    await DatabaseHelper.instance.deleteDatabaseFile();
    await const FlutterSecureStorage().deleteAll();
    await (await SharedPreferences.getInstance()).clear();
    try {
      final logos = Directory(p.join((await getApplicationDocumentsDirectory()).path, 'operator_logos'));
      if (await logos.exists()) await logos.delete(recursive: true);
    } catch (_) {}
  }
}
