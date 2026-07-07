import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../session/session_store.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(sessionStoreProvider));
});

class ApiClient {
  ApiClient(this._sessionStore, {http.Client? client})
      : _client = client ?? http.Client();

  final SessionStore _sessionStore;
  final http.Client _client;
  static const _timeout = Duration(seconds: 18);

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, String>? query,
  }) async {
    final uri = _uri(path, query);
    try {
      final response =
          await _client.get(uri, headers: await _headers()).timeout(_timeout);
      return _decode(response);
    } on TimeoutException {
      throw ApiException('The backend did not respond. Check the API URL.');
    }
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(_uri(path), headers: await _headers(), body: jsonEncode(body))
          .timeout(_timeout);
      return _decode(response);
    } on TimeoutException {
      throw ApiException('The backend did not respond. Check the API URL.');
    }
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    try {
      final response = await _client
          .delete(_uri(path), headers: await _headers())
          .timeout(_timeout);
      return _decode(response);
    } on TimeoutException {
      throw ApiException('The backend did not respond. Check the API URL.');
    }
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = AppConfig.apiBaseUrl.endsWith('/')
        ? AppConfig.apiBaseUrl.substring(0, AppConfig.apiBaseUrl.length - 1)
        : AppConfig.apiBaseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<Map<String, String>> _headers() async {
    final token = await _sessionStore.readToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Token $token',
    };
  }

  Map<String, dynamic> _decode(http.Response response) {
    final body = _tryDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(_errorMessage(body, response.statusCode));
    }
    return body is Map<String, dynamic> ? body : {'data': body};
  }

  Object _tryDecode(String responseBody) {
    if (responseBody.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(responseBody);
    } on FormatException {
      return {'detail': responseBody};
    }
  }

  String _errorMessage(Object body, int statusCode) {
    if (body is Map<String, dynamic>) {
      final detail = body['detail'];
      if (detail != null) return detail.toString();
      final messages = body.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join('\n');
      if (messages.isNotEmpty) return messages;
    }
    return 'Request failed with $statusCode.';
  }
}

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}
