import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

class SessionStore {
  static const _tokenKey = 'auth_token';
  static const _displayNameKey = 'display_name';
  static const _anonymousIncidentTokenKey = 'anonymous_incident_token';

  Future<String?> readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<String?> readDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_displayNameKey);
  }

  Future<void> save({
    required String token,
    required String displayName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    await prefs.setString(_displayNameKey, displayName);
  }

  Future<String> readOrCreateAnonymousIncidentToken() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_anonymousIncidentTokenKey);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure().nextInt(0x3fffffff);
    final token = 'anon-${DateTime.now().microsecondsSinceEpoch}-$random';
    await prefs.setString(_anonymousIncidentTokenKey, token);
    return token;
  }

  Future<void> saveAnonymousIncidentToken(String token) async {
    if (token.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_anonymousIncidentTokenKey, token);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_displayNameKey);
  }
}
