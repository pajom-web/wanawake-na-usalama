import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/html.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class JsonWebSocket {
  JsonWebSocket(String url) {
    _channel = HtmlWebSocketChannel.connect(Uri.parse(url));
    _subscription = _channel.stream.listen(
      (message) {
        final decoded = jsonDecode(message as String) as Map<String, dynamic>;
        _controller.add(decoded);
      },
      onError: _controller.addError,
      onDone: _controller.close,
    );
  }

  late final WebSocketChannel _channel;
  late final StreamSubscription<dynamic> _subscription;
  final StreamController<Map<String, dynamic>> _controller =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;

  void ping() {
    _channel.sink.add(jsonEncode({'event': 'ping'}));
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _channel.sink.close();
    await _controller.close();
  }
}
