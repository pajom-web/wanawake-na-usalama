import 'package:flutter/material.dart';

abstract final class TacticalColors {
  static Color background = const Color(0xFF0D0F12);
  static Color surface = const Color(0xFF161A20);
  static Color surfaceRaised = const Color(0xFF1B2027);
  static Color border = const Color(0xFF2A313B);
  static Color borderStrong = const Color(0xFF3A4552);
  static Color text = const Color(0xFFF4F7FA);
  static Color textMuted = const Color(0xFF8D99A6);
  static const critical = Color(0xFFFF3B30);
  static const pending = Color(0xFFFF9500);
  static const active = Color(0xFF34C759);
  static const low = Color(0xFF5AC8FA);
  static const blue = Color(0xFF007AFF);
  static const onAccent = Color(0xFF0D0F12);

  static void useBrightness(Brightness brightness) {
    if (brightness == Brightness.light) {
      background = const Color(0xFFF3F6F8);
      surface = const Color(0xFFFFFFFF);
      surfaceRaised = const Color(0xFFE8EEF2);
      border = const Color(0xFFD5DEE5);
      borderStrong = const Color(0xFFAAB8C4);
      text = const Color(0xFF17212B);
      textMuted = const Color(0xFF5D6B78);
      return;
    }
    background = const Color(0xFF0D0F12);
    surface = const Color(0xFF161A20);
    surfaceRaised = const Color(0xFF1B2027);
    border = const Color(0xFF2A313B);
    borderStrong = const Color(0xFF3A4552);
    text = const Color(0xFFF4F7FA);
    textMuted = const Color(0xFF8D99A6);
  }
}

ThemeData buildTacticalTheme(Brightness brightness) {
  TacticalColors.useBrightness(brightness);
  final scheme = ColorScheme.fromSeed(
    seedColor: TacticalColors.active,
    brightness: brightness,
    surface: TacticalColors.surface,
    error: TacticalColors.critical,
  );

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: TacticalColors.background,
    useMaterial3: true,
    dividerColor: TacticalColors.border,
    textTheme: TextTheme(
      headlineSmall: TextStyle(
        color: TacticalColors.text,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: TacticalColors.text,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: TextStyle(
        color: TacticalColors.text,
        fontWeight: FontWeight.w700,
      ),
      bodyMedium: TextStyle(color: TacticalColors.textMuted, height: 1.4),
      bodySmall: TextStyle(color: TacticalColors.textMuted, height: 1.35),
      labelLarge: TextStyle(
        color: TacticalColors.text,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: TacticalColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: TacticalColors.border),
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: TacticalColors.background,
      foregroundColor: TacticalColors.text,
      elevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
      shape: Border(bottom: BorderSide(color: TacticalColors.border)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TacticalColors.background,
      labelStyle: TextStyle(color: TacticalColors.textMuted),
      hintStyle: TextStyle(color: TacticalColors.textMuted),
      prefixIconColor: TacticalColors.textMuted,
      border: OutlineInputBorder(
        borderSide: BorderSide(color: TacticalColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: TacticalColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: TacticalColors.active, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TacticalColors.active,
        foregroundColor: TacticalColors.onAccent,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.6,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TacticalColors.text,
        side: BorderSide(color: TacticalColors.borderStrong),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: TacticalColors.textMuted,
        side: BorderSide(color: TacticalColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? TacticalColors.surfaceRaised
              : TacticalColors.background,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? TacticalColors.active
              : TacticalColors.textMuted,
        ),
        side: WidgetStatePropertyAll(BorderSide(color: TacticalColors.border)),
        textStyle: const WidgetStatePropertyAll(
          TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.4),
        ),
      ),
    ),
  );
}

class TacticalPanel extends StatelessWidget {
  const TacticalPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? TacticalColors.surface,
        border: Border.all(color: borderColor ?? TacticalColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }
}

class TacticalEyebrow extends StatelessWidget {
  const TacticalEyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: color ?? TacticalColors.textMuted,
        fontSize: 11,
        fontWeight: FontWeight.w900,
        letterSpacing: 1.5,
      ),
    );
  }
}

TextStyle tacticalMono({
  Color? color,
  double fontSize = 12,
  FontWeight fontWeight = FontWeight.w700,
}) {
  return TextStyle(
    color: color ?? TacticalColors.text,
    fontFamily: 'monospace',
    fontSize: fontSize,
    fontWeight: fontWeight,
    letterSpacing: 0.4,
  );
}
