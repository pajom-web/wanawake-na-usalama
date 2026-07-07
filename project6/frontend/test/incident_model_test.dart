import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/incident.dart';

void main() {
  test('incident model parses IoT alert metadata', () {
    final incident = Incident.fromJson({
      'id': 'iot-alert-1',
      'anonymous_token': 'iot-token',
      'category': 'SOS',
      'status': 'REPORTED',
      'severity': 'CRITICAL',
      'latitude': -6.7924,
      'longitude': 39.2083,
      'description': 'IoT panic button pressed.',
      'reporter_phone': '',
      'assigned_unit': '',
      'police_notes': '',
      'source': 'IOT_BUTTON',
      'device_id': 'esp32-node-001',
      'pressed_at': '2026-06-14T09:20:30Z',
      'created_at': '2026-06-14T09:20:31Z',
      'updated_at': '2026-06-14T09:20:31Z',
    });

    expect(incident.isIotButton, isTrue);
    expect(incident.deviceId, 'esp32-node-001');
    expect(incident.pressedAt, DateTime.parse('2026-06-14T09:20:30Z'));
  });

  test('incident model parses central resolution audit metadata', () {
    final incident = Incident.fromJson({
      'id': 'resolved-alert-1',
      'anonymous_token': 'resolution-token',
      'category': 'SOS',
      'status': 'RESOLVED',
      'severity': 'CRITICAL',
      'latitude': -6.7924,
      'longitude': 39.2083,
      'description': 'Resolved incident.',
      'reporter_phone': '',
      'assigned_unit': '',
      'police_notes': '',
      'solved_by_name': 'Officer Joseph Field',
      'solved_by_badge_number': 'TZ-FIELD-22',
      'solved_by_station': 'North District Station',
      'solved_at': '2026-06-15T10:21:30Z',
      'source': 'CITIZEN_APP',
      'device_id': '',
      'pressed_at': null,
      'created_at': '2026-06-14T09:20:31Z',
      'updated_at': '2026-06-15T10:21:30Z',
    });

    expect(incident.hasResolutionDetails, isTrue);
    expect(incident.solvedByName, 'Officer Joseph Field');
    expect(incident.solvedByBadgeNumber, 'TZ-FIELD-22');
    expect(incident.solvedByStation, 'North District Station');
    expect(incident.solvedAt, DateTime.parse('2026-06-15T10:21:30Z'));
  });
}
