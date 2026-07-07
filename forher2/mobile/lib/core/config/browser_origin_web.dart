import 'package:web/web.dart' as web;

String browserOrigin() => web.window.location.origin;

String browserWsOrigin() {
  final location = web.window.location;
  final protocol = location.protocol == 'https:' ? 'wss:' : 'ws:';
  return '$protocol//${location.host}';
}
