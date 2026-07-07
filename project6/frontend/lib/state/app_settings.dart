import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

enum AppLanguage { english, swahili }

enum AppAppearance { dark, light }

class AppSettings {
  const AppSettings({required this.language, required this.appearance});

  final AppLanguage language;
  final AppAppearance appearance;

  Locale get locale => Locale(language == AppLanguage.swahili ? 'sw' : 'en');

  Brightness get brightness =>
      appearance == AppAppearance.light ? Brightness.light : Brightness.dark;

  AppSettings copyWith({AppLanguage? language, AppAppearance? appearance}) {
    return AppSettings(
      language: language ?? this.language,
      appearance: appearance ?? this.appearance,
    );
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
      return AppSettingsController();
    });

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController()
    : super(
        AppSettings(
          language: web.window.localStorage.getItem(_languageKey) == 'sw'
              ? AppLanguage.swahili
              : AppLanguage.english,
          appearance: web.window.localStorage.getItem(_appearanceKey) == 'light'
              ? AppAppearance.light
              : AppAppearance.dark,
        ),
      );

  static const _languageKey = 'safety_mobility_language';
  static const _appearanceKey = 'safety_mobility_appearance';

  void setLanguage(AppLanguage language) {
    state = state.copyWith(language: language);
    web.window.localStorage.setItem(
      _languageKey,
      language == AppLanguage.swahili ? 'sw' : 'en',
    );
  }

  void setAppearance(AppAppearance appearance) {
    state = state.copyWith(appearance: appearance);
    web.window.localStorage.setItem(
      _appearanceKey,
      appearance == AppAppearance.light ? 'light' : 'dark',
    );
  }
}
