import 'package:flutter/material.dart';

class SafetyColors {
  static const canvas = Color(0xFF0B0B0D);
  static const surface = Color(0xFF16161A);
  static const accent = Color(0xFFFF3B30);
  static const warning = Color(0xFFFF9500);
  static const safe = Color(0xFF34C759);
  static const primaryText = Color(0xFFFFFFFF);
  static const secondaryText = Color(0xFF8E8E93);
  static const mutedMetric = Color(0xFF9A9A12);
  static const handle = Color(0xFF3A3A3C);
}

class SafetyPalette extends ThemeExtension<SafetyPalette> {
  const SafetyPalette({
    required this.canvas,
    required this.surface,
    required this.accent,
    required this.warning,
    required this.safe,
    required this.primaryText,
    required this.secondaryText,
    required this.mutedMetric,
    required this.handle,
    required this.outline,
  });

  final Color canvas;
  final Color surface;
  final Color accent;
  final Color warning;
  final Color safe;
  final Color primaryText;
  final Color secondaryText;
  final Color mutedMetric;
  final Color handle;
  final Color outline;

  static const dark = SafetyPalette(
    canvas: SafetyColors.canvas,
    surface: SafetyColors.surface,
    accent: SafetyColors.accent,
    warning: SafetyColors.warning,
    safe: SafetyColors.safe,
    primaryText: SafetyColors.primaryText,
    secondaryText: SafetyColors.secondaryText,
    mutedMetric: SafetyColors.mutedMetric,
    handle: SafetyColors.handle,
    outline: Color(0x22FFFFFF),
  );

  static const light = SafetyPalette(
    canvas: Color(0xFFF6F7FB),
    surface: Color(0xFFFFFFFF),
    accent: Color(0xFFD92D20),
    warning: Color(0xFFB86B00),
    safe: Color(0xFF168A45),
    primaryText: Color(0xFF17181C),
    secondaryText: Color(0xFF666B78),
    mutedMetric: Color(0xFF757900),
    handle: Color(0xFFC9CDD6),
    outline: Color(0x1F17181C),
  );

  @override
  SafetyPalette copyWith({
    Color? canvas,
    Color? surface,
    Color? accent,
    Color? warning,
    Color? safe,
    Color? primaryText,
    Color? secondaryText,
    Color? mutedMetric,
    Color? handle,
    Color? outline,
  }) {
    return SafetyPalette(
      canvas: canvas ?? this.canvas,
      surface: surface ?? this.surface,
      accent: accent ?? this.accent,
      warning: warning ?? this.warning,
      safe: safe ?? this.safe,
      primaryText: primaryText ?? this.primaryText,
      secondaryText: secondaryText ?? this.secondaryText,
      mutedMetric: mutedMetric ?? this.mutedMetric,
      handle: handle ?? this.handle,
      outline: outline ?? this.outline,
    );
  }

  @override
  SafetyPalette lerp(ThemeExtension<SafetyPalette>? other, double t) {
    if (other is! SafetyPalette) return this;
    return SafetyPalette(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      safe: Color.lerp(safe, other.safe, t)!,
      primaryText: Color.lerp(primaryText, other.primaryText, t)!,
      secondaryText: Color.lerp(secondaryText, other.secondaryText, t)!,
      mutedMetric: Color.lerp(mutedMetric, other.mutedMetric, t)!,
      handle: Color.lerp(handle, other.handle, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
    );
  }
}

extension SafetyColorLookup on BuildContext {
  SafetyPalette get safetyColors =>
      Theme.of(this).extension<SafetyPalette>() ?? SafetyPalette.dark;
}
