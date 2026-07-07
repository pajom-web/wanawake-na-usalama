import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/config/app_config.dart';
import '../data/hotspot_repository.dart';
import '../domain/hotspot.dart';

final hotspotListProvider =
    AsyncNotifierProvider<HotspotListController, List<Hotspot>>(
  HotspotListController.new,
);

class HotspotListController extends AsyncNotifier<List<Hotspot>> {
  static const defaultCenter = LatLng(-6.7924, 39.2083);

  LatLng _lastPoint = defaultCenter;
  Timer? _refreshTimer;
  WebSocketChannel? _hotspotChannel;
  StreamSubscription<dynamic>? _hotspotSubscription;

  @override
  Future<List<Hotspot>> build() {
    _lastPoint = defaultCenter;
    _connectHotspotSocket();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_refreshSilently());
    });
    ref.onDispose(() {
      _refreshTimer?.cancel();
      _hotspotSubscription?.cancel();
      _hotspotChannel?.sink.close();
    });
    return _fetch(defaultCenter);
  }

  Future<void> refreshAround(LatLng point) async {
    _lastPoint = point;
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _fetch(point));
  }

  Future<List<Hotspot>> _fetch(LatLng point) {
    return ref
        .read(hotspotRepositoryProvider)
        .fetch(latitude: point.latitude, longitude: point.longitude);
  }

  Future<void> _refreshSilently() async {
    final current = state.valueOrNull;
    final refreshed = await AsyncValue.guard(() => _fetch(_lastPoint));
    if (refreshed.hasError && current != null) return;
    state = refreshed;
  }

  void _connectHotspotSocket() {
    try {
      final uri = Uri.parse(AppConfig.wsBaseUrl).replace(
        path: '/ws/citizen/hotspots/',
      );
      _hotspotChannel = WebSocketChannel.connect(uri);
      _hotspotSubscription = _hotspotChannel!.stream.listen((message) {
        try {
          final decoded = jsonDecode(message.toString());
          if (decoded is Map<String, dynamic>) {
            final event = decoded['event']?.toString();
            if (event != null && event.startsWith('hotspot.')) {
              unawaited(_refreshSilently());
            }
          }
        } on FormatException {
          // Ignore malformed messages; periodic REST refresh remains active.
        }
      }, onError: (_, __) {
        // A blocked websocket must not surface as an uncaught UI exception.
      });
    } catch (_) {
      // Periodic polling still keeps the map current when websockets are blocked.
    }
  }
}
