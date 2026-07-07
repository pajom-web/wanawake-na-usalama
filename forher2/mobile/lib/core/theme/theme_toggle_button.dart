import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../localization/app_localizations.dart';
import 'safety_colors.dart';
import 'theme_controller.dart';

class ThemeToggleButton extends ConsumerWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.safetyColors;
    final themeMode =
        ref.watch(themeControllerProvider).valueOrNull ?? ThemeMode.dark;
    final isDark = themeMode == ThemeMode.dark;
    final l10n = context.l10n;

    return IconButton(
      tooltip: isDark ? l10n.switchToLightMode : l10n.switchToDarkMode,
      onPressed: () => ref.read(themeControllerProvider.notifier).toggle(),
      icon: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        color: colors.primaryText,
      ),
      style: IconButton.styleFrom(
        backgroundColor: colors.surface,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: colors.outline),
      ),
    );
  }
}
