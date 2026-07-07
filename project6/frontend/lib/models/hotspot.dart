class Hotspot {
  const Hotspot({
    required this.id,
    required this.title,
    required this.centerLatitude,
    required this.centerLongitude,
    required this.radiusMeters,
    required this.riskLevel,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
    this.expiresAt,
    this.source = 'MANUAL',
    this.incidentCount = 0,
  });

  final int id;
  final String title;
  final double centerLatitude;
  final double centerLongitude;
  final int radiusMeters;
  final String riskLevel;
  final bool active;
  final String notes;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String source;
  final int incidentCount;

  bool get isAutomatic => source == 'AUTOMATIC';

  factory Hotspot.fromJson(Map<String, dynamic> json) {
    return Hotspot(
      id: json['id'] as int,
      title: json['title'] as String,
      centerLatitude: _asDouble(json['center_latitude']),
      centerLongitude: _asDouble(json['center_longitude']),
      radiusMeters: json['radius_meters'] as int,
      riskLevel: json['risk_level'] as String,
      active: json['active'] as bool? ?? true,
      notes: json['notes'] as String? ?? '',
      source: json['source'] as String? ?? 'MANUAL',
      incidentCount: json['incident_count'] as int? ?? 0,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'title': title,
      'center_latitude': centerLatitude,
      'center_longitude': centerLongitude,
      'radius_meters': radiusMeters,
      'risk_level': riskLevel,
      'active': active,
      'notes': notes,
      'expires_at': expiresAt?.toIso8601String(),
    };
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.parse(value.toString());
  }
}
