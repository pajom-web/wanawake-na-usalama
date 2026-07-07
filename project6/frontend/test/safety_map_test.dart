import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/widgets/safety_map.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('citizen map exposes zoom controls in read-only mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [AppLocalizationsDelegate()],
        home: const Scaffold(
          body: SizedBox(
            width: 800,
            height: 600,
            child: SafetyMap(
              center: LatLng(-6.7924, 39.2083),
              showCenterMarker: false,
              showZoomControls: true,
              showBaseMap: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);

    await tester.tap(find.byTooltip('Zoom in'));
    await tester.pump();
    await tester.tap(find.byTooltip('Zoom out'));
    await tester.pump();
  });
}
