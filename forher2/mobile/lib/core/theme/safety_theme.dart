import 'package:flutter/material.dart';

import 'safety_colors.dart';

class SafetyTheme {
  static ThemeData get light {
    return _build(
      brightness: Brightness.light,
      colors: SafetyPalette.light,
    );
  }

  static ThemeData get dark {
    return _build(
      brightness: Brightness.dark,
      colors: SafetyPalette.dark,
    );
  }

  static ThemeData _build({
    required Brightness brightness,
    required SafetyPalette colors,
  }) {
    return ThemeData(
      brightness: brightness,
      scaffoldBackgroundColor: colors.canvas,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.accent,
        brightness: brightness,
      ).copyWith(
        primary: colors.accent,
        secondary: colors.warning,
        surface: colors.surface,
        error: colors.accent,
      ),
      fontFamily: 'Roboto',
      extensions: [colors],
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.accent, width: 1.4),
        ),
        labelStyle: TextStyle(color: colors.secondaryText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          backgroundColor: colors.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(Size(48, 48)),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
    );
  }
}
