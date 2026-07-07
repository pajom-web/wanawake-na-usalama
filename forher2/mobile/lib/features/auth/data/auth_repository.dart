import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_store.dart';
import '../domain/auth_session.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  );
});

class AuthRepository {
  AuthRepository(this._api, this._sessionStore);

  final ApiClient _api;
  final SessionStore _sessionStore;

  Future<AuthSession?> restore() async {
    try {
      final token = await _sessionStore.readToken().timeout(
            const Duration(seconds: 3),
          );
      if (token == null) return null;
      final payload = await _api.getJson('/auth/me/');
      return _persist(payload);
    } catch (_) {
      await _sessionStore.clear();
      return null;
    }
  }

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final payload = await _api.postJson('/auth/login/', {
      'username': username,
      'password': password,
    });
    return _persist(payload);
  }

  Future<AuthSession> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
    String phoneNumber = '',
  }) async {
    final payload = await _api.postJson('/auth/register/', {
      'username': username,
      'email': email,
      'password': password,
      'display_name': displayName,
      if (phoneNumber.isNotEmpty) 'phone_number': phoneNumber,
    });
    return _persist(payload);
  }

  Future<void> logout() async {
    try {
      await _api.postJson('/auth/logout/', const {});
    } catch (_) {
      // Local logout must still complete if the token expired or the network is down.
    } finally {
      await _sessionStore.clear();
    }
  }

  Future<AuthSession> _persist(Map<String, dynamic> payload) async {
    final token = payload['token']?.toString();
    final displayName = payload['display_name']?.toString();
    if (token == null || token.isEmpty) {
      throw ApiException('The backend returned an invalid login session.');
    }
    final session = AuthSession(
      token: token,
      displayName: displayName == null || displayName.isEmpty
          ? 'Safe rider'
          : displayName,
    );
    await _sessionStore.save(
      token: session.token,
      displayName: session.displayName,
    );
    return session;
  }
}
