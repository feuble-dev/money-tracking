import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';

/// Flag de progression de l'onboarding (type de compte, agence, catalogue
/// importé) — suit la même convention que isPinSetProvider (auth_provider.dart)
/// pour que le router puisse gater l'accès tant qu'il n'est pas true.
class OnboardingStatusService {
  static const _key = 'onboarding_complete';
  static const _accountTypeKey = 'account_type';

  Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_key) == true) return true;

    // Comptes déjà actifs avant cette version (migration DB v8 -> v9) : le
    // backfill crée toujours une agence par défaut. Une install neuve (v9
    // dès _onCreate) n'a elle aucune agence tant que l'onboarding n'a pas
    // tourné — c'est ce qui distingue "déjà agent" de "premier lancement".
    final db = await DatabaseHelper.instance.database;
    final agences = await db.query('agences', limit: 1);
    if (agences.isNotEmpty) {
      await markComplete();
      return true;
    }
    return false;
  }

  Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Persisté pour filtrer le catalogue (cible_compte) lors des resync
  /// futurs (ex: ajout d'une nouvelle agence, Phase 6), pas seulement au
  /// premier lancement.
  Future<void> saveAccountType(String accountType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accountTypeKey, accountType);
  }

  Future<String?> getAccountType() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accountTypeKey);
  }
}

final onboardingStatusServiceProvider =
    Provider<OnboardingStatusService>((ref) => OnboardingStatusService());

final isOnboardingCompleteProvider = FutureProvider<bool>((ref) async {
  final service = ref.read(onboardingStatusServiceProvider);
  return service.isComplete();
});

/// Type de compte choisi à l'onboarding ('particulier'|'agence') — pilote
/// les différences d'interface mobile entre les deux profils (D7), ex:
/// onglet Commissions masqué pour un compte Particulier. Défaut 'agence'
/// tant que la valeur n'a pas encore été persistée (comptes déjà actifs
/// avant l'introduction de ce champ, migration v8 -> v9).
final accountTypeProvider = FutureProvider<String>((ref) async {
  final service = ref.read(onboardingStatusServiceProvider);
  return (await service.getAccountType()) ?? 'agence';
});
