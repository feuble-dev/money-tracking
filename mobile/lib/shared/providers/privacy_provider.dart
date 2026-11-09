import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Masquer/afficher les montants (soldes, totaux) — un seul réglage pour
/// toute l'app, retenu d'une ouverture à l'autre (on consulte souvent son
/// argent en public).
class BalanceVisibility extends Notifier<bool> {
  static const _key = 'balances_visible';

  @override
  bool build() {
    SharedPreferences.getInstance().then((p) {
      final saved = p.getBool(_key);
      if (saved != null && saved != state) state = saved;
    });
    return true;
  }

  void toggle() {
    state = !state;
    SharedPreferences.getInstance().then((p) => p.setBool(_key, state));
  }
}

final balanceVisibleProvider =
    NotifierProvider<BalanceVisibility, bool>(BalanceVisibility.new);
