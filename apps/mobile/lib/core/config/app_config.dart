class AppConfig {
  static const bool isRelease = bool.fromEnvironment('dart.vm.product');

  static const apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: isRelease
        ? 'https://prava-99tv.onrender.com/api'
        : 'http://10.0.2.2:3000/api',
  );

  static const wsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: isRelease
        ? 'wss://prava-99tv.onrender.com'
        : 'ws://10.0.2.2:3001',
  );
}
