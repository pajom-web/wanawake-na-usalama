class PatrolAsset {
  const PatrolAsset({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    this.notes = '',
  });

  final int id;
  final String name;
  final double latitude;
  final double longitude;
  final String status;
  final bool active;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PatrolAsset.fromJson(Map<String, dynamic> json) {
    return PatrolAsset(
      id: json['id'] as int,
      name: json['name'] as String,
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      status: json['status'] as String,
      active: json['active'] as bool? ?? true,
      notes: json['notes'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'status': status,
      'active': active,
      'notes': notes,
    };
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.parse(value.toString());
  }
}
