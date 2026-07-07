class Incident {
  const Incident({
    required this.id,
    required this.category,
    required this.status,
    required this.severity,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.updatedAt,
    this.anonymousToken,
    this.description = '',
    this.reporterPhone = '',
    this.assignedUnit = '',
    this.policeNotes = '',
    this.solvedByName = '',
    this.solvedByBadgeNumber = '',
    this.solvedByStation = '',
    this.solvedAt,
    this.source = 'CITIZEN_APP',
    this.deviceId = '',
    this.pressedAt,
  });

  final String id;
  final String? anonymousToken;
  final String category;
  final String status;
  final String severity;
  final double latitude;
  final double longitude;
  final String description;
  final String reporterPhone;
  final String assignedUnit;
  final String policeNotes;
  final String solvedByName;
  final String solvedByBadgeNumber;
  final String solvedByStation;
  final DateTime? solvedAt;
  final String source;
  final String deviceId;
  final DateTime? pressedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isIotButton => source == 'IOT_BUTTON';
  bool get hasResolutionDetails =>
      solvedByName.isNotEmpty || solvedByStation.isNotEmpty || solvedAt != null;

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as String,
      anonymousToken: json['anonymous_token'] as String?,
      category: json['category'] as String,
      status: json['status'] as String,
      severity: json['severity'] as String,
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      description: json['description'] as String? ?? '',
      reporterPhone: json['reporter_phone'] as String? ?? '',
      assignedUnit: json['assigned_unit'] as String? ?? '',
      policeNotes: json['police_notes'] as String? ?? '',
      solvedByName: json['solved_by_name'] as String? ?? '',
      solvedByBadgeNumber: json['solved_by_badge_number'] as String? ?? '',
      solvedByStation: json['solved_by_station'] as String? ?? '',
      solvedAt: _optionalDateTime(json['solved_at']),
      source: json['source'] as String? ?? 'CITIZEN_APP',
      deviceId: json['device_id'] as String? ?? '',
      pressedAt: _optionalDateTime(json['pressed_at']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Incident copyWith({
    String? status,
    String? assignedUnit,
    String? policeNotes,
    String? solvedByName,
    String? solvedByBadgeNumber,
    String? solvedByStation,
    DateTime? solvedAt,
    bool clearSolvedAt = false,
  }) {
    return Incident(
      id: id,
      anonymousToken: anonymousToken,
      category: category,
      status: status ?? this.status,
      severity: severity,
      latitude: latitude,
      longitude: longitude,
      description: description,
      reporterPhone: reporterPhone,
      assignedUnit: assignedUnit ?? this.assignedUnit,
      policeNotes: policeNotes ?? this.policeNotes,
      solvedByName: solvedByName ?? this.solvedByName,
      solvedByBadgeNumber: solvedByBadgeNumber ?? this.solvedByBadgeNumber,
      solvedByStation: solvedByStation ?? this.solvedByStation,
      solvedAt: clearSolvedAt ? null : solvedAt ?? this.solvedAt,
      source: source,
      deviceId: deviceId,
      pressedAt: pressedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static double _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.parse(value.toString());
  }

  static DateTime? _optionalDateTime(Object? value) {
    if (value == null || value.toString().isEmpty) {
      return null;
    }
    return DateTime.parse(value.toString());
  }
}
