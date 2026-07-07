import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/l10n/app_localizations.dart';
import 'package:frontend/theme/tactical_theme.dart';

void main() {
  test('English and Swahili translations are available', () {
    const english = AppLocalizations(Locale('en'));
    const swahili = AppLocalizations(Locale('sw'));

    expect(english.t('app.dispatch'), 'Police Dispatcher');
    expect(english.t('router.brokenStreetlights'), 'Broken Streetlights');
    expect(swahili.t('app.dispatch'), 'Mpokeaji wa Polisi');
    expect(swahili.code('RESOLVED'), 'IMETATULIWA');
  });

  test('unknown status codes fall back to their original label', () {
    const localizations = AppLocalizations(Locale('sw'));

    expect(localizations.code('CUSTOM_STATUS'), 'CUSTOM STATUS');
  });

  test('tactical theme supports light and dark appearances', () {
    final light = buildTacticalTheme(Brightness.light);
    expect(light.brightness, Brightness.light);
    expect(TacticalColors.background, const Color(0xFFF3F6F8));

    final dark = buildTacticalTheme(Brightness.dark);
    expect(dark.brightness, Brightness.dark);
    expect(TacticalColors.background, const Color(0xFF0D0F12));
  });
}
