import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gender_sensitive_safety/main.dart';

void main() {
  testWidgets('shows authentication screen when no session is stored', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const ProviderScope(child: SafetyApp()));
    await _pumpUntilFound(tester, find.text('Secure login'));

    expect(find.text('SafeRoute'), findsOneWidget);
    expect(find.text('Secure login'), findsOneWidget);
  });
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  int maxPumps = 20,
}) async {
  for (var pump = 0; pump < maxPumps; pump++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) return;
  }
}
