import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/safety_colors.dart';
import 'app_localizations.dart';
import 'locale_controller.dart';

class LanguageToggleButton extends ConsumerWidget {
  const LanguageToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.safetyColors;
    final l10n = context.l10n;

    return PopupMenuButton<Locale>(
      tooltip: l10n.changeLanguage,
      onSelected: (locale) {
        ref.read(localeControllerProvider.notifier).setLocale(locale);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: const Locale('en'),
          child: Text(l10n.english),
        ),
        PopupMenuItem(
          value: const Locale('sw'),
          child: Text(l10n.swahili),
        ),
      ],
      icon: Icon(Icons.translate_outlined, color: colors.primaryText),
      style: IconButton.styleFrom(
        backgroundColor: colors.surface,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: colors.outline),
      ),
    );
  }
}
