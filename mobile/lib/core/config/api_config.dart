/// Adresse du backend — un seul endroit au lieu d'une constante recopiée
/// dans 8 fichiers. Surchargeable au build pour pointer un serveur local :
///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api
class ApiConfig {
  ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.money-tracking.site/api',
  );

  static const String licence = '$baseUrl/licence';
  static const String sync = '$baseUrl/sync';
  static const String catalog = '$baseUrl/catalog';
}
