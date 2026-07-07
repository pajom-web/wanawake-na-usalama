import 'package:web/web.dart' as web;

class AppConfig {
  static const _configuredApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const _configuredWsBaseUrl = String.fromEnvironment(
    'WS_BASE_URL',
    defaultValue: 'ws://localhost:8000',
  );

  static String get apiBaseUrl {
    if (_configuredApiBaseUrl == 'same-origin') {
      return web.window.location.origin;
    }
    return _matchBrowserLoopbackHost(_configuredApiBaseUrl);
  }

  static String get wsBaseUrl {
    if (_configuredWsBaseUrl == 'same-origin') {
      final location = web.window.location;
      final protocol = location.protocol == 'https:' ? 'wss:' : 'ws:';
      return '$protocol//${location.host}';
    }
    return _matchBrowserLoopbackHost(_configuredWsBaseUrl);
  }

  static Uri apiUri(String path) => Uri.parse('$apiBaseUrl$path');

  static String get policeAlertsWsUrl => '$wsBaseUrl/ws/police/alerts/';
  static String get citizenHotspotsWsUrl => '$wsBaseUrl/ws/citizen/hotspots/';

  static String _matchBrowserLoopbackHost(String configuredUrl) {
    final configured = Uri.parse(configuredUrl);
    final browserHost = web.window.location.hostname;
    if (_isLoopback(configured.host) &&
        _isLoopback(browserHost) &&
        configured.host != browserHost) {
      return configured.replace(host: browserHost).toString();
    }
    return configuredUrl;
  }

  static bool _isLoopback(String host) {
    return host == 'localhost' || host == '127.0.0.1' || host == '::1';
  }
}
