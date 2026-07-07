import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeControllerProvider =
    AsyncNotifierProvider<ThemeController, ThemeMode>(ThemeController.new);

class ThemeController extends AsyncNotifier<ThemeMode> {
  static const _themeModeKey = 'theme_mode';

  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themeModeKey);
    return stored == ThemeMode.light.name ? ThemeMode.light : ThemeMode.dark;
  }

  Future<void> toggle() async {
    final current = state.valueOrNull ?? ThemeMode.dark;
    final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = AsyncData(next);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, next.name);
  }
}
