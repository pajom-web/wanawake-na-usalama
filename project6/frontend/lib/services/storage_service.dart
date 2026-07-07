import 'dart:math';

import 'package:web/web.dart' as web;

class StorageService {
  static const _anonymousTokenKey = 'safety_mobility_anonymous_token';

  String getOrCreateAnonymousToken() {
    final existing = web.window.localStorage.getItem(_anonymousTokenKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final random = Random.secure().nextInt(0x3fffffff);
    final token = 'anon-${DateTime.now().microsecondsSinceEpoch}-$random';
    web.window.localStorage.setItem(_anonymousTokenKey, token);
    return token;
  }

  void setAnonymousToken(String token) {
    web.window.localStorage.setItem(_anonymousTokenKey, token);
  }
}
