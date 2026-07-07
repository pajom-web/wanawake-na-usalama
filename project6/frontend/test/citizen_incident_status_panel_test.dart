import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/models/incident.dart';
import 'package:frontend/widgets/citizen_incident_status_panel.dart';

void main() {
  testWidgets('citizen report tracker shows dispatch status updates', (
    tester,
  ) async {
    final now = DateTime.now();
    final incidents = [
      _incident('acknowledged-report', 'ACKNOWLEDGED', now),
      _incident('dispatched-report', 'DISPATCHED', now),
      _incident('resolved-report', 'RESOLVED', now),
    ];

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizationsDelegate()],
        home: Scaffold(
          body: SingleChildScrollView(
            child: CitizenIncidentStatusPanel(
              incidents: incidents,
              onRefresh: () async {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('ACKNOWLEDGED'), findsOneWidget);
    expect(find.text('DISPATCHED'), findsOneWidget);
    expect(find.text('RESOLVED'), findsOneWidget);
    expect(
      find.text('Police dispatcher has acknowledged your report.'),
      findsOneWidget,
    );
    expect(find.text('A response has been dispatched.'), findsOneWidget);
    expect(
      find.text('Police dispatcher marked this report as resolved.'),
      findsOneWidget,
    );
  });
}

Incident _incident(String id, String status, DateTime updatedAt) {
  return Incident(
    id: id,
    category: 'SOS',
    status: status,
    severity: 'HIGH',
    latitude: -6.7924,
    longitude: 39.2083,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}
