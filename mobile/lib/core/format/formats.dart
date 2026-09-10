import 'package:intl/intl.dart';

/// Formats partagés — évite de ré-instancier un `NumberFormat`/`DateFormat`
/// dans chaque écran. `NumberFormat` n'est pas const : on les garde en
/// singletons paresseux.
class AppFormats {
  AppFormats._();

  static final NumberFormat currency = NumberFormat.currency(
      locale: 'fr_FR', symbol: 'FCFA', decimalDigits: 0);

  static final NumberFormat compact =
      NumberFormat.compact(locale: 'fr_FR');

  static final DateFormat date = DateFormat('dd/MM/yyyy', 'fr_FR');
  static final DateFormat dateTime = DateFormat('dd/MM/yyyy HH:mm', 'fr_FR');
  static final DateFormat dayMonth = DateFormat('d MMM', 'fr_FR');

  static String fcfa(num value) => currency.format(value);
}
