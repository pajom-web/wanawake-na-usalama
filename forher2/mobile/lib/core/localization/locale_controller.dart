import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_localizations.dart';

final localeControllerProvider =
    AsyncNotifierProvider<LocaleController, Locale?>(LocaleController.new);

class LocaleController extends AsyncNotifier<Locale?> {
  static const _localeKey = 'app_locale';

  @override
  Future<Locale?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_localeKey);
    if (stored == null) return null;

    for (final locale in AppLocalizations.supportedLocales) {
      if (locale.languageCode == stored) return locale;
    }
    return null;
  }

  Future<void> setLocale(Locale locale) async {
    state = AsyncData(locale);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
  }
}
