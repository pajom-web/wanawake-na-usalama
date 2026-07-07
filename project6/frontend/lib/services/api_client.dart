import 'dart:convert';

import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/hotspot.dart';
import '../models/incident.dart';
import '../models/patrol_asset.dart';
import '../models/safety_tip.dart';

class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient() : _client = BrowserClient()..withCredentials = true;

  final BrowserClient _client;

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Future<Map<String, dynamic>> health() async {
    return _decodeMap(await _client.get(AppConfig.apiUri('/api/health/')));
  }

  Future<Incident> createIncident({
    required String anonymousToken,
    required double latitude,
    required double longitude,
    String category = 'SOS',
    String severity = 'CRITICAL',
    String description = '',
    String reporterPhone = '',
  }) async {
    final response = await _client.post(
      AppConfig.apiUri('/api/incidents/'),
      headers: _headers,
      body: jsonEncode({
        'anonymous_token': anonymousToken,
        'category': category,
        'severity': severity,
        'latitude': latitude,
        'longitude': longitude,
        'description': description,
        'reporter_phone': reporterPhone,
      }),
    );
    return Incident.fromJson(_decodeMap(response));
  }

  Future<List<Incident>> fetchCitizenIncidents(String anonymousToken) async {
    final encodedToken = Uri.encodeComponent(anonymousToken);
    final response = await _client.get(
      AppConfig.apiUri('/api/incidents/status/$encodedToken/'),
    );
    return _decodeList(response).map(Incident.fromJson).toList();
  }

  Future<List<Hotspot>> fetchPublicHotspots() async {
    final response = await _client.get(AppConfig.apiUri('/api/hotspots/'));
    return _decodeList(response).map(Hotspot.fromJson).toList();
  }

  Future<Map<String, dynamic>> loginPolice({
    required String username,
    required String password,
  }) async {
    final response = await _client.post(
      AppConfig.apiUri('/api/police/login/'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _decodeMap(response);
  }

  Future<void> logoutPolice() async {
    final response = await _client.post(
      AppConfig.apiUri('/api/police/logout/'),
      headers: _headers,
    );
    _ensureOk(response);
  }

  Future<Map<String, dynamic>> fetchPoliceMe() async {
    return _decodeMap(await _client.get(AppConfig.apiUri('/api/police/me/')));
  }

  Future<List<Incident>> fetchPoliceIncidents() async {
    final response = await _client.get(
      AppConfig.apiUri('/api/police/incidents/'),
    );
    return _decodeList(response).map(Incident.fromJson).toList();
  }

  Future<Incident> updateIncidentStatus(String id, String status) async {
    final response = await _client.patch(
      AppConfig.apiUri('/api/police/incidents/$id/'),
      headers: _headers,
      body: jsonEncode({'status': status}),
    );
    return Incident.fromJson(_decodeMap(response));
  }

  Future<List<Hotspot>> fetchPoliceHotspots() async {
    final response = await _client.get(
      AppConfig.apiUri('/api/police/hotspots/'),
    );
    return _decodeList(response).map(Hotspot.fromJson).toList();
  }

  Future<Hotspot> createHotspot(Hotspot hotspot) async {
    final response = await _client.post(
      AppConfig.apiUri('/api/police/hotspots/'),
      headers: _headers,
      body: jsonEncode(hotspot.toCreateJson()),
    );
    return Hotspot.fromJson(_decodeMap(response));
  }

  Future<Hotspot> updateHotspotRisk(int id, String riskLevel) async {
    final response = await _client.patch(
      AppConfig.apiUri('/api/police/hotspots/$id/'),
      headers: _headers,
      body: jsonEncode({'risk_level': riskLevel}),
    );
    return Hotspot.fromJson(_decodeMap(response));
  }

  Future<void> deactivateHotspot(int id) async {
    final response = await _client.delete(
      AppConfig.apiUri('/api/police/hotspots/$id/'),
      headers: _headers,
    );
    _ensureOk(response);
  }

  Future<List<PatrolAsset>> fetchPolicePatrolAssets() async {
    final response = await _client.get(
      AppConfig.apiUri('/api/police/patrol-assets/'),
    );
    return _decodeList(response).map(PatrolAsset.fromJson).toList();
  }

  Future<PatrolAsset> createPatrolAsset(PatrolAsset asset) async {
    final response = await _client.post(
      AppConfig.apiUri('/api/police/patrol-assets/'),
      headers: _headers,
      body: jsonEncode(asset.toCreateJson()),
    );
    return PatrolAsset.fromJson(_decodeMap(response));
  }

  Future<PatrolAsset> updatePatrolAsset(
    int id, {
    double? latitude,
    double? longitude,
    String? status,
  }) async {
    final payload = <String, dynamic>{};
    if (latitude != null) {
      payload['latitude'] = latitude;
    }
    if (longitude != null) {
      payload['longitude'] = longitude;
    }
    if (status != null) {
      payload['status'] = status;
    }
    final response = await _client.patch(
      AppConfig.apiUri('/api/police/patrol-assets/$id/'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return PatrolAsset.fromJson(_decodeMap(response));
  }

  Future<void> deactivatePatrolAsset(int id) async {
    final response = await _client.delete(
      AppConfig.apiUri('/api/police/patrol-assets/$id/'),
      headers: _headers,
    );
    _ensureOk(response);
  }

  Future<List<SafetyTip>> fetchPoliceSafetyTips() async {
    final response = await _client.get(
      AppConfig.apiUri('/api/police/safety-tips/'),
    );
    return _decodeList(response).map(SafetyTip.fromJson).toList();
  }

  Future<SafetyTip> createSafetyTip(SafetyTip tip) async {
    final response = await _client.post(
      AppConfig.apiUri('/api/police/safety-tips/'),
      headers: _headers,
      body: jsonEncode(tip.toWriteJson()),
    );
    return SafetyTip.fromJson(_decodeMap(response));
  }

  Future<SafetyTip> updateSafetyTip(SafetyTip tip) async {
    final response = await _client.patch(
      AppConfig.apiUri('/api/police/safety-tips/${tip.id}/'),
      headers: _headers,
      body: jsonEncode(tip.toWriteJson()),
    );
    return SafetyTip.fromJson(_decodeMap(response));
  }

  Future<void> deactivateSafetyTip(int id) async {
    final response = await _client.delete(
      AppConfig.apiUri('/api/police/safety-tips/$id/'),
      headers: _headers,
    );
    _ensureOk(response);
  }

  Future<void> close() async {
    _client.close();
  }

  List<Map<String, dynamic>> _decodeList(http.Response response) {
    _ensureOk(response);
    final decoded = jsonDecode(response.body) as List<dynamic>;
    return decoded.cast<Map<String, dynamic>>();
  }

  Map<String, dynamic> _decodeMap(http.Response response) {
    _ensureOk(response);
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  void _ensureOk(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }
    String? detail;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      detail = decoded['detail']?.toString();
    } catch (_) {
      detail = null;
    }
    if (detail != null && detail.isNotEmpty) {
      throw ApiException(detail);
    }
    throw ApiException(
      'Request failed with HTTP ${response.statusCode}: ${response.body}',
    );
  }
}
