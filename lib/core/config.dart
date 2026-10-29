/// Configuração em tempo de build.
///
/// Endereço da API: `flutter run -d chrome --dart-define=API_BASE_URL=https://api.exemplo.com`.
/// O padrão aponta para a API local do protótipo.
abstract final class AppConfig {
  static const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'http://localhost:8080');
}
