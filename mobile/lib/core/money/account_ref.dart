/// Référence vers un « compte » d'argent du Particulier, sérialisée en base
/// (`wallet_entries.account` / `counter_account`) :
/// - `wallet:<id>` : compte tenu à la main (espèces, banque, épargne…) ;
/// - `momo:<operatorId>` : portefeuille Mobile Money, dont le solde vient
///   des SMS de l'opérateur (jamais modifié à la main).
class AccountRef {
  final bool isMobileMoney;
  final String id;

  const AccountRef.wallet(this.id) : isMobileMoney = false;
  const AccountRef.momo(this.id) : isMobileMoney = true;

  static AccountRef? tryParse(String? raw) {
    if (raw == null) return null;
    final i = raw.indexOf(':');
    if (i <= 0) return null;
    final id = raw.substring(i + 1);
    if (id.isEmpty) return null;
    return switch (raw.substring(0, i)) {
      'wallet' => AccountRef.wallet(id),
      'momo' => AccountRef.momo(id),
      _ => null,
    };
  }

  String get raw => isMobileMoney ? 'momo:$id' : 'wallet:$id';

  @override
  bool operator ==(Object other) =>
      other is AccountRef && other.raw == raw;

  @override
  int get hashCode => raw.hashCode;

  @override
  String toString() => raw;
}
