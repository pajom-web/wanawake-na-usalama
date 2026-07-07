import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/app_localizations.dart';
import 'core/localization/locale_controller.dart';
import 'core/theme/safety_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/presentation/auth_controller.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/map/presentation/safety_map_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: SafetyApp()));
}

class SafetyApp extends ConsumerWidget {
  const SafetyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider);
    final themeMode =
        ref.watch(themeControllerProvider).valueOrNull ?? ThemeMode.dark;
    final locale = ref.watch(localeControllerProvider).valueOrNull;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SafeRoute',
      theme: SafetyTheme.light,
      darkTheme: SafetyTheme.dark,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: session.when(
        data: (value) =>
            value == null ? const LoginScreen() : const SafetyMapScreen(),
        error: (_, __) => const LoginScreen(),
        loading: () => const _BootScreen(),
      ),
    );
  }
}

class _BootScreen extends StatelessWidget {
  const _BootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
