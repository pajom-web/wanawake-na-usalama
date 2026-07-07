import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/hotspot.dart';

final hotspotRepositoryProvider = Provider<HotspotRepository>((ref) {
  return HotspotRepository(ref.watch(apiClientProvider));
});

class HotspotRepository {
  HotspotRepository(this._api);

  final ApiClient _api;

  Future<List<Hotspot>> fetch({
    required double latitude,
    required double longitude,
    double radiusKm = 3,
  }) async {
    final payload = await _api.getJson(
      '/hotspots/',
      query: {
        'latitude': latitude.toStringAsFixed(6),
        'longitude': longitude.toStringAsFixed(6),
        'radius_km': radiusKm.toStringAsFixed(1),
      },
    );
    final data = payload['hotspots'] ?? payload['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(Hotspot.fromJson)
        .toList();
  }
}
