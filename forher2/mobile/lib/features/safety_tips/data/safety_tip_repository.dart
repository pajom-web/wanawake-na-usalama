import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/safety_tip.dart';

final safetyTipRepositoryProvider = Provider<SafetyTipRepository>((ref) {
  return SafetyTipRepository(ref.watch(apiClientProvider));
});

class SafetyTipRepository {
  SafetyTipRepository(this._api);

  final ApiClient _api;

  Future<List<SafetyTip>> fetchTips() async {
    final payload = await _api.getJson('/safety-tips/');
    final data = payload['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(SafetyTip.fromJson)
        .toList();
  }
}
