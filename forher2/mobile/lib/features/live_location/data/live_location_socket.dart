import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../../../core/session/session_store.dart';

final liveLocationSocketProvider = Provider<LiveLocationSocket>((ref) {
  return LiveLocationSocket(ref.watch(sessionStoreProvider));
});

class LiveLocationSocket {
  LiveLocationSocket(this._sessionStore);

  final SessionStore _sessionStore;
  WebSocketChannel? _channel;

  Future<void> connect(String sessionToken) async {
    final token = await _sessionStore.readToken();
    if (token == null) throw StateError('Missing auth token.');
    final uri = Uri.parse(AppConfig.wsBaseUrl).replace(
      path: '/ws/live-location/',
      queryParameters: {'token': token, 'session': sessionToken},
    );
    _channel = WebSocketChannel.connect(uri);
  }

  void sendLocation(LatLng point) {
    _send(
      jsonEncode({
        'type': 'location.update',
        'latitude': point.latitude,
        'longitude': point.longitude,
        'sent_at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  void sendEnd() {
    _send(jsonEncode({'type': 'session.end'}));
  }

  Future<void> close() async {
    await _channel?.sink.close();
    _channel = null;
  }

  void _send(String payload) {
    try {
      _channel?.sink.add(payload);
    } catch (_) {
      _channel = null;
    }
  }
}
