import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

final liveTrackingRepositoryProvider = Provider<LiveTrackingRepository>((ref) {
  return LiveTrackingRepository(ref.watch(apiClientProvider));
});

class LiveTrackingRepository {
  LiveTrackingRepository(this._api);

  final ApiClient _api;

  Future<LiveTrackingSessionRef> createSession() async {
    final payload = await _api.postJson('/tracking-sessions/', {
      'metadata': {},
    });
    return LiveTrackingSessionRef(
      id: payload['id'] as int,
      sessionToken: payload['session_token'] as String,
    );
  }

  Future<void> revokeSession(int id) async {
    await _api.deleteJson('/tracking-sessions/$id/');
  }
}

class LiveTrackingSessionRef {
  const LiveTrackingSessionRef({
    required this.id,
    required this.sessionToken,
  });

  final int id;
  final String sessionToken;
}
