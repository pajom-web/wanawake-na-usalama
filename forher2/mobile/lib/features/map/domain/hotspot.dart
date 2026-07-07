import 'package:latlong2/latlong.dart';

class Hotspot {
  const Hotspot({
    required this.id,
    required this.title,
    required this.point,
    required this.incidentCount,
    required this.riskScore,
    required this.riskLevel,
    required this.dominantCategory,
    required this.radiusMeters,
    this.notes = '',
    this.active = true,
    this.source = 'MANUAL',
  });

  final int id;
  final String title;
  final LatLng point;
  final int incidentCount;
  final int riskScore;
  final String riskLevel;
  final String dominantCategory;
  final int radiusMeters;
  final String notes;
  final bool active;
  final String source;

  bool get isAutomatic => source == 'AUTOMATIC';

  factory Hotspot.fromJson(Map<String, dynamic> json) {
    final riskLevel = json['risk_level']?.toString() ?? 'HIGH';
    final radiusMeters = _readInt(json['radius_meters']) ?? 80;
    return Hotspot(
      id: _readInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? 'Police hotspot',
      point: LatLng(
        _readDouble(json['center_latitude'] ?? json['latitude']),
        _readDouble(json['center_longitude'] ?? json['longitude']),
      ),
      incidentCount: _readInt(json['incident_count']) ?? 1,
      riskScore:
          _readInt(json['risk_score']) ?? (riskLevel == 'HIGH' ? 90 : 35),
      riskLevel: riskLevel,
      dominantCategory: json['dominant_category']?.toString() ?? 'POLICE',
      radiusMeters: radiusMeters,
      notes: json['notes']?.toString() ?? '',
      active: json['active'] != false,
      source: json['source']?.toString() ?? 'MANUAL',
    );
  }
}

double _readDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

int? _readInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}
