import 'browser_origin.dart';

class AppConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.219.203.170:8000/api',
  );

  static const _configuredWsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://10.219.203.170:8000',
  );

  static String get apiBaseUrl {
    if (_configuredApiBaseUrl == 'same-origin') {
      final origin = browserOrigin();
      if (origin != null) {
        return '$origin/api';
      }
    }
    return _configuredApiBaseUrl;
  }

  static String get wsBaseUrl {
    if (_configuredWsBaseUrl == 'same-origin') {
      final origin = browserWsOrigin();
      if (origin != null) {
        return origin;
      }
    }
    return _configuredWsBaseUrl;
  }
}
