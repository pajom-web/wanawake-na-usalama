import 'package:flutter_test/flutter_test.dart';

import 'package:gender_sensitive_safety/features/map/presentation/safety_map_screen.dart';
import 'package:gender_sensitive_safety/features/report/data/incident_repository.dart';

void main() {
  test('empty incident history has no latest status', () {
    expect(latestIncidentStatus(const []), isNull);
    expect(latestIncidentStatus(null), isNull);
  });

  test('latest incident status comes from the first report', () {
    final incidents = [
      IncidentReportSummary(
        id: 'incident-1',
        category: 'HARASSMENT',
        riskLevel: 'HIGH',
        status: 'DISPATCHED',
        severity: 'HIGH',
        title: 'Harassment',
        description: '',
        latitude: -6.8,
        longitude: 39.2,
        occurredAt: DateTime.utc(2026, 6, 18),
        isVerified: false,
      ),
    ];

    expect(latestIncidentStatus(incidents), 'DISPATCHED');
  });
}
