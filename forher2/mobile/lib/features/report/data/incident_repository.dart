import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/network/api_client.dart';
import '../../../core/session/session_store.dart';
import '../domain/incident_type.dart';

final incidentRepositoryProvider = Provider<IncidentRepository>((ref) {
  return IncidentRepository(
    ref.watch(apiClientProvider),
    ref.watch(sessionStoreProvider),
  );
});

class IncidentRepository {
  IncidentRepository(this._api, this._sessionStore);

  final ApiClient _api;
  final SessionStore _sessionStore;

  Future<List<IncidentReportSummary>> fetchHistory() async {
    final token = await _sessionStore.readOrCreateAnonymousIncidentToken();
    final payload = await _api.getJson('/incidents/status/$token/');
    final data = payload['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map<String, dynamic>>()
        .map(IncidentReportSummary.fromJson)
        .toList();
  }

  Future<IncidentReportReceipt> report({
    required IncidentType type,
    required LatLng point,
    required String title,
    String description = '',
    String riskLevel = 'moderate',
  }) async {
    final token = await _sessionStore.readOrCreateAnonymousIncidentToken();
    final payload = await _api.postJson('/incidents/', {
      'anonymous_token': token,
      'category': type.apiValue,
      'severity': _severityForRisk(riskLevel),
      'description': description,
      'latitude': point.latitude.toStringAsFixed(6),
      'longitude': point.longitude.toStringAsFixed(6),
    });
    final receipt = IncidentReportReceipt.fromJson(payload);
    await _sessionStore.saveAnonymousIncidentToken(
      receipt.anonymousToken ?? token,
    );
    return receipt;
  }

  String _severityForRisk(String riskLevel) {
    return switch (riskLevel.toUpperCase()) {
      'LOW' => 'LOW',
      'HIGH' => 'HIGH',
      'CRITICAL' => 'CRITICAL',
      _ => 'MEDIUM',
    };
  }
}

class IncidentReportSummary {
  const IncidentReportSummary({
    required this.id,
    required this.category,
    required this.riskLevel,
    required this.status,
    required this.severity,
    required this.title,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.occurredAt,
    required this.isVerified,
  });

  final String? id;
  final String category;
  final String riskLevel;
  final String status;
  final String severity;
  final String title;
  final String description;
  final double latitude;
  final double longitude;
  final DateTime? occurredAt;
  final bool isVerified;

  factory IncidentReportSummary.fromJson(Map<String, dynamic> json) {
    return IncidentReportSummary(
      id: json['id']?.toString(),
      category: json['category']?.toString() ?? '',
      riskLevel:
          json['risk_level']?.toString() ?? json['severity']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      severity: json['severity']?.toString() ?? '',
      title: json['title']?.toString() ?? json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      latitude: _readDouble(json['latitude']),
      longitude: _readDouble(json['longitude']),
      occurredAt: (json['occurred_at'] ?? json['created_at']) is String
          ? DateTime.tryParse(
              (json['occurred_at'] ?? json['created_at']) as String)
          : null,
      isVerified: json['is_verified'] == true || json['status'] == 'RESOLVED',
    );
  }
}

class IncidentReportReceipt {
  const IncidentReportReceipt({
    required this.id,
    this.anonymousToken,
    this.createdAt,
  });

  final String? id;
  final String? anonymousToken;
  final DateTime? createdAt;

  factory IncidentReportReceipt.fromJson(Map<String, dynamic> json) {
    final createdAt = json['created_at'];
    return IncidentReportReceipt(
      id: json['id']?.toString(),
      anonymousToken: json['anonymous_token']?.toString(),
      createdAt: createdAt is String ? DateTime.tryParse(createdAt) : null,
    );
  }
}

double _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
