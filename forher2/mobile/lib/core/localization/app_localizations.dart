import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('en'),
    Locale('sw'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  bool get _isSwahili => locale.languageCode == 'sw';

  String _text(String english, String swahili) {
    return _isSwahili ? swahili : english;
  }

  String get appTitle => 'SafeRoute';
  String get changeLanguage => _text('Change language', 'Badilisha lugha');
  String get english => _text('English', 'Kiingereza');
  String get swahili => _text('Kiswahili', 'Kiswahili');
  String get switchToLightMode =>
      _text('Switch to light mode', 'Badili kwenda mandhari meupe');
  String get switchToDarkMode =>
      _text('Switch to dark mode', 'Badili kwenda mandhari meusi');
  String get logout => _text('Logout', 'Ondoka');

  String get brandCopy => _text(
        'Move through the city with live routing and risk-aware map context.',
        'Tembea mjini ukiwa na njia za moja kwa moja na ramani inayoonyesha maeneo ya tahadhari.',
      );
  String get login => _text('Login', 'Ingia');
  String get register => _text('Register', 'Jisajili');
  String get username => _text('Username', 'Jina la mtumiaji');
  String get displayName => _text('Display name', 'Jina la kuonyesha');
  String get email => _text('Email', 'Barua pepe');
  String get password => _text('Password', 'Nenosiri');
  String get showPassword => _text('Show password', 'Onyesha nenosiri');
  String get hidePassword => _text('Hide password', 'Ficha nenosiri');
  String get createAccount => _text('Create account', 'Fungua akaunti');
  String get secureLogin => _text('Secure login', 'Ingia salama');
  String get trustStrip => _text(
        'Your device keeps an anonymous report token so police status updates can be shown here.',
        'Kifaa chako huhifadhi tokeni ya ripoti isiyojulikana ili hali iliyosasishwa na polisi ionekane hapa.',
      );

  String fieldRequired(String field) {
    return _text('$field is required', '$field inahitajika');
  }

  String get refreshHotspots =>
      _text('Refresh hotspots', 'Onyesha upya maeneo hatari');
  String get reportIncident => _text('Report incident', 'Ripoti tukio');
  String get safetyTips => _text('Safety tips', 'Vidokezo vya usalama');
  String get incidentHistory =>
      _text('Incident history', 'Historia ya matukio');
  String get noSafetyTips =>
      _text('No safety tips available', 'Hakuna vidokezo vya usalama');
  String get noIncidentHistory =>
      _text('No incident reports yet', 'Hakuna ripoti za matukio bado');
  String get retry => _text('Retry', 'Jaribu tena');
  String get verified => _text('Verified', 'Imethibitishwa');
  String get pendingReview => _text('Pending review', 'Inasubiri ukaguzi');
  String get location => _text('Location', 'Mahali');
  String get adminUpdatedTips => _text(
      'Admin-updated safety tips', 'Vidokezo vilivyosasishwa na msimamizi');
  String get liveTracking =>
      _text('Live tracking', 'Ufuatiliaji wa moja kwa moja');
  String get sendingReport => _text('Sending report', 'Inatuma ripoti');
  String reportReceived(String? reportId) {
    if (reportId == null) {
      return _text('Report received', 'Ripoti imepokelewa');
    }
    return _text('Report received #$reportId', 'Ripoti imepokelewa #$reportId');
  }

  String reportStatusUpdated(String status) {
    final englishStatus = switch (status) {
      'ACKNOWLEDGED' => 'Acknowledged',
      'DISPATCHED' => 'Dispatched',
      'RESOLVED' => 'Resolved',
      'FALSE_ALARM' => 'False alarm',
      _ => 'Reported',
    };
    final swahiliStatus = switch (status) {
      'ACKNOWLEDGED' => 'Imekubaliwa',
      'DISPATCHED' => 'Askari wametumwa',
      'RESOLVED' => 'Imetatuliwa',
      'FALSE_ALARM' => 'Tahadhari si sahihi',
      _ => 'Imeripotiwa',
    };
    return _text(
      'Report status: $englishStatus',
      'Hali ya ripoti: $swahiliStatus',
    );
  }

  String get reportNotReceived =>
      _text('Report not received', 'Ripoti haijapokelewa');
  String get liveLocationActive =>
      _text('Live location active', 'Mahali pa moja kwa moja panatumika');
  String get riskMapReady =>
      _text('Risk map ready', 'Ramani ya hatari iko tayari');
  String get backendNeedsAttention => _text(
        'Backend connection needs attention',
        'Muunganisho wa seva unahitaji kuangaliwa',
      );
  String get loadingHotspotZones =>
      _text('Loading hotspot zones', 'Inapakia maeneo hatari');
  String activeHotspotZonesNearby(int count) {
    return _text(
      '$count active hotspot zones nearby',
      '$count maeneo hatari yanayotumika karibu',
    );
  }

  String get retryHotspotFetch =>
      _text('Retry hotspot fetch', 'Jaribu tena kupakia maeneo hatari');
  String get optionalNotes => _text('Optional notes', 'Maelezo ya hiari');
  String get submitReport => _text('Submit report', 'Tuma ripoti');
  String reportSubmitFailed(String error) {
    return _text(
      'Report not received. $error',
      'Ripoti haijapokelewa. $error',
    );
  }

  String get harassment => _text('Harassment', 'Unyanyasaji');
  String get poorLighting => _text('Poor lighting', 'Mwanga hafifu');
  String get unsafeStreet => _text('Unsafe street', 'Barabara si salama');
  String get desertedArea => _text('Deserted area', 'Eneo lisilo na watu');
  String get suspiciousActivity =>
      _text('Suspicious activity', 'Shughuli ya kutiliwa shaka');
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any(
      (supportedLocale) => supportedLocale.languageCode == locale.languageCode,
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
