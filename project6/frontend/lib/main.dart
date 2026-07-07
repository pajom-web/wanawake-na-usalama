import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n/app_localizations.dart';
import 'pages/citizen_page.dart';
import 'pages/police_dashboard_page.dart';
import 'state/app_settings.dart';
import 'theme/tactical_theme.dart';

void main() {
  runApp(ProviderScope(child: SafetyMobilityApp()));
}

enum AppMode { citizen, police }

class SafetyMobilityApp extends ConsumerWidget {
  const SafetyMobilityApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.l10n.t('app.title'),
      locale: settings.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: buildTacticalTheme(settings.brightness),
      home: AppShell(),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  AppMode _mode = AppMode.citizen;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    final settings = ref.watch(appSettingsProvider);
    final settingsController = ref.read(appSettingsProvider.notifier);
    final l10n = context.l10n;
    final commandTitle = _mode == AppMode.police
        ? l10n.t('app.policeCommand')
        : l10n.t('app.citizenCommand');
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shield_outlined, color: TacticalColors.active),
            if (!compact) ...[
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    commandTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: SegmentedButton<AppMode>(
              segments: [
                ButtonSegment(
                  value: AppMode.citizen,
                  label: Text(
                    compact ? l10n.t('app.router') : l10n.t('app.secureRouter'),
                  ),
                  icon: Icon(Icons.route_outlined),
                ),
                ButtonSegment(
                  value: AppMode.police,
                  label: Text(l10n.t('app.dispatch')),
                  icon: Icon(Icons.local_police_outlined),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (selection) {
                setState(() => _mode = selection.first);
              },
            ),
          ),
          PopupMenuButton<AppLanguage>(
            tooltip: l10n.t('settings.language'),
            initialValue: settings.language,
            onSelected: settingsController.setLanguage,
            icon: Icon(Icons.language),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: AppLanguage.english,
                child: Text(l10n.t('settings.english')),
              ),
              PopupMenuItem(
                value: AppLanguage.swahili,
                child: Text(l10n.t('settings.swahili')),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(right: 10),
            child: PopupMenuButton<AppAppearance>(
              tooltip: l10n.t('settings.appearance'),
              initialValue: settings.appearance,
              onSelected: settingsController.setAppearance,
              icon: Icon(
                settings.appearance == AppAppearance.dark
                    ? Icons.dark_mode_outlined
                    : Icons.light_mode_outlined,
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: AppAppearance.dark,
                  child: Text(l10n.t('settings.dark')),
                ),
                PopupMenuItem(
                  value: AppAppearance.light,
                  child: Text(l10n.t('settings.light')),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _mode == AppMode.citizen ? CitizenPage() : PoliceDashboardPage(),
    );
  }
}
