import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [Locale('en'), Locale('sw')];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String t(String key, [Map<String, Object> parameters = const {}]) {
    var value =
        (_values[locale.languageCode] ?? _values['en']!)[key] ??
        _values['en']![key] ??
        key;
    for (final entry in parameters.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value.toString());
    }
    return value;
  }

  String code(String value) {
    final key = 'code.$value';
    final translated = t(key);
    return (translated == key ? value : translated).replaceAll('_', ' ');
  }

  String error(String message) {
    if (message.contains('Invalid police username or password') ||
        message.contains('Invalid username or password')) {
      return t('error.invalidPoliceCredentials');
    }
    if (message.contains('Enter both username and password')) {
      return t('error.enterCredentials');
    }
    if (message.contains('Unable to establish the police session')) {
      return t('error.session');
    }
    if (message.contains('Location unavailable')) {
      return t('error.location');
    }
    return message;
  }

  static const _values = <String, Map<String, String>>{
    'en': {
      'app.title': 'SAFETY POLICE DASHBOARD',
      'app.command': 'SAFETY POLICE DASHBOARD',
      'app.citizenCommand': 'Safety dashboard',
      'app.policeCommand': 'SAFETY POLICE DASHBOARD',
      'app.subtitle': '',
      'app.router': 'Router',
      'app.secureRouter': 'Secure Router',
      'app.dispatch': 'Police Dispatcher',
      'settings.language': 'Language',
      'settings.english': 'English',
      'settings.swahili': 'Swahili',
      'settings.appearance': 'Appearance',
      'settings.dark': 'Dark theme',
      'settings.light': 'Light theme',
      'login.restricted': 'Restricted operations',
      'login.title': 'POLICE DISPATCHER ACCESS',
      'login.instructions':
          'Use the username and password issued with your police record by the system administrator.',
      'login.username': 'Officer username',
      'login.password': 'Secure password',
      'login.submit': 'ESTABLISH SECURE SESSION',
      'error.invalidPoliceCredentials': 'Invalid police username or password.',
      'error.enterCredentials': 'Enter both username and password.',
      'error.session': 'Unable to establish the police session.',
      'error.location': 'Location is unavailable.',
      'router.districtStatus': 'DISTRICT STATUS: 5 UNITS LIVE',
      'router.riskZones': '{count} RISK ZONES',
      'router.deviceReports': '{count} REPORTS FROM THIS DEVICE',
      'router.useLocation': 'USE MY LOCATION',
      'router.refresh': 'Refresh district data',
      'router.map': 'Public Risk Map',
      'router.mapDetail':
          'View-only high and low risk areas from police dispatcher',
      'router.tapMap': 'READ ONLY - PAN OR ZOOM TO EXPLORE RISK AREAS',
      'router.selectedTarget': 'Selected Grid Target',
      'router.currentLocation': 'Current Report Location',
      'router.activeZones': '{count} ACTIVE ZONES',
      'router.title': 'Secure Router',
      'router.reportTitle': 'Report threat or vulnerability',
      'router.instructions':
          'Provide gender-sensitive mobility incidents or transit hazard parameters below to optimize immediate field-unit placement.',
      'router.incidentType': 'Incident type',
      'router.priority': 'Assigned triage priority',
      'router.locationDetails': 'Location and specifics',
      'router.safeEscort': 'Safe Escort Passage',
      'router.emergencySos': 'Emergency SOS',
      'router.harassment': 'Harassment Report',
      'router.stalking': 'Stalking Concerns',
      'router.medical': 'Medical Assistance',
      'router.brokenStreetlights': 'Broken Streetlights',
      'router.location': 'Specific location',
      'router.locationHint': 'University Science Campus Lane C',
      'router.notes': 'Detailed notes',
      'router.notesHint': 'Enter incident tags or operational details',
      'router.phone': 'Secure callback number (optional)',
      'router.cancel': 'CANCEL',
      'router.submit': 'SUBMIT FORM',
      'router.coordinates': 'Coordinates pre-fill',
      'router.activeIncident': 'Active incident',
      'router.reportStatus': 'Your Report Status',
      'router.reportStatusHelp':
          'Police dispatcher updates appear here automatically.',
      'router.refreshReportStatus': 'Refresh report status',
      'router.lastUpdated': 'Updated {time}',
      'router.statusReported':
          'Report received and waiting for acknowledgement.',
      'router.statusAcknowledged':
          'Police dispatcher has acknowledged your report.',
      'router.statusDispatched': 'A response has been dispatched.',
      'router.statusResolved':
          'Police dispatcher marked this report as resolved.',
      'router.statusFalseAlarm':
          'Police dispatcher closed this report as a false alarm.',
      'map.zoomIn': 'Zoom in',
      'map.zoomOut': 'Zoom out',
      'dispatch.liveFeed': 'LIVE FEED',
      'dispatch.history': 'HISTORICAL LOGS',
      'dispatch.analytics': 'ANALYTICS',
      'dispatch.pendingSos': '{count} PENDING SOS',
      'dispatch.hotspots': '{count} HOTSPOTS',
      'dispatch.stable': 'SYSTEM STATE: STABLE',
      'dispatch.offline': 'SYSTEM OFFLINE',
      'dispatch.refresh': 'Refresh police dispatcher telemetry',
      'dispatch.logout': 'End police session',
      'dispatch.officer': 'OFFICER',
      'dispatch.noBadge': 'NO BADGE',
      'dispatch.unassignedStation': 'UNASSIGNED STATION',
      'dispatch.incidentFeed': 'Incident Active Feed',
      'dispatch.priorityQueue': 'Priority queue',
      'dispatch.all': 'ALL',
      'dispatch.severe': 'SEVERE',
      'dispatch.pending': 'PENDING',
      'dispatch.closed': 'CLOSED',
      'dispatch.noIncidents': 'No incidents match this queue.',
      'dispatch.examine': 'EXAMINE  →',
      'dispatch.iotButtonAlert': 'IoT Panic Button Alert',
      'dispatch.iotPanicButton': 'IoT panic button',
      'dispatch.source': 'Source',
      'dispatch.device': 'Device',
      'dispatch.unknownDevice': 'Unknown device',
      'dispatch.pressedAt': 'Pressed at',
      'dispatch.reportedAt': 'Reported at',
      'dispatch.resolutionAudit': 'CENTRAL RESOLUTION AUDIT',
      'dispatch.solvedBy': 'Solved by',
      'dispatch.solvedByStation': 'Officer station',
      'dispatch.solvedAt': 'Solved at',
      'dispatch.operationsMap': 'Interactive Operations Map',
      'dispatch.responseTelemetry': 'Active response telemetry',
      'dispatch.patrolAssets': 'PATROL ASSETS',
      'dispatch.dangerAlerts': 'DANGER ALERTS',
      'dispatch.riskHigh': 'HIGH RISK',
      'dispatch.riskLow': 'LOW RISK',
      'dispatch.patrolAsset': 'PATROL ASSET',
      'dispatch.escort': 'ESCORT',
      'dispatch.zoomIn': 'Zoom in',
      'dispatch.zoomOut': 'Zoom out',
      'dispatch.centerGrid': 'Center grid',
      'dispatch.threatIntelligence': 'Threat Intelligence',
      'dispatch.hotspotManagement': 'Hotspot management',
      'dispatch.mapLayerManagement': 'Police dispatcher map management',
      'dispatch.closeDrawing': 'CLOSE DRAWING MODE',
      'dispatch.drawHotspot': '+ DRAW UNSAFE HOTSPOT',
      'dispatch.hotspotHelp': 'How to mark a hotspot',
      'dispatch.hotspotInstructions':
          'Tap the operations map, then create or update a low/high risk area or patrol asset.',
      'dispatch.noHotspots': 'No registered hotspots in this district.',
      'dispatch.registeredHotspots': 'Registered Hotspots',
      'dispatch.active': '{count} ACTIVE',
      'dispatch.radiusRisk': '{radius}m radius · {risk} risk',
      'dispatch.automaticZone': 'AUTOMATIC · {count} REPORTS',
      'dispatch.manualZone': 'POLICE ADDED',
      'dispatch.drawingActive': 'Drawing Mode Active',
      'dispatch.tapCoordinates': 'Tap the map to pre-fill grid coordinates.',
      'dispatch.zoneTitle': 'Zone title',
      'dispatch.latitude': 'Latitude',
      'dispatch.longitude': 'Longitude',
      'dispatch.radius': 'Radius meters',
      'dispatch.riskLevel': 'Risk level',
      'dispatch.operatorNotes': 'Operator notes',
      'dispatch.registerHotspot': 'REGISTER HOTSPOT',
      'dispatch.invalidCoordinates': 'Enter valid coordinates and radius.',
      'dispatch.unsafeZone': 'Unsafe zone',
      'dispatch.setLowRisk': 'Set low risk',
      'dispatch.setHighRisk': 'Set high risk',
      'dispatch.deactivate': 'Deactivate',
      'dispatch.noPatrolAssets': 'No active patrol assets in this district.',
      'dispatch.registeredPatrolAssets': 'Registered Patrol Assets',
      'dispatch.moveHere': 'MOVE HERE',
      'dispatch.patrolAssetManagement': 'Register Patrol Asset',
      'dispatch.patrolAssetInstructions':
          'Tap the operations map, then register the patrol asset at that point.',
      'dispatch.assetName': 'Patrol asset name',
      'dispatch.assetStatus': 'Patrol asset status',
      'dispatch.registerPatrolAsset': 'REGISTER PATROL ASSET',
      'dispatch.invalidPatrolAsset':
          'Enter an asset name and select a point on the map.',
      'dispatch.safetyTips': 'Mobile Safety Tips',
      'dispatch.safetyTipsHelp':
          'Central Police can publish and update guidance shown in the mobile app.',
      'dispatch.tipTitle': 'Tip title',
      'dispatch.tipBody': 'Safety guidance',
      'dispatch.tipCategory': 'Category (optional)',
      'dispatch.tipOrder': 'Order',
      'dispatch.publishTip': 'PUBLISH TIP',
      'dispatch.updateTip': 'UPDATE TIP',
      'dispatch.cancelEdit': 'Cancel editing',
      'dispatch.noSafetyTips': 'No active mobile safety tips.',
      'dispatch.invalidSafetyTip': 'Enter a title, guidance, and valid order.',
      'dispatch.edit': 'EDIT',
      'incident.sos': 'Emergency SOS Alert',
      'incident.harassment': 'Harassment Report',
      'incident.stalking': 'Stalking Concerns',
      'incident.medical': 'Medical Assistance',
      'incident.escort': 'Safe Escort Passage',
      'incident.brokenStreetlights': 'Broken Streetlights',
      'code.LOW': 'LOW',
      'code.MEDIUM': 'MEDIUM',
      'code.HIGH': 'HIGH',
      'code.CRITICAL': 'CRITICAL',
      'code.AVAILABLE': 'AVAILABLE',
      'code.DEPLOYED': 'DEPLOYED',
      'code.OFFLINE': 'OFFLINE',
      'code.REPORTED': 'REPORTED',
      'code.ACKNOWLEDGED': 'ACKNOWLEDGED',
      'code.DISPATCHED': 'DISPATCHED',
      'code.RESOLVED': 'RESOLVED',
      'code.FALSE_ALARM': 'FALSE ALARM',
      'code.SOS': 'SOS',
      'code.HARASSMENT': 'HARASSMENT',
      'code.STALKING': 'STALKING',
      'code.MEDICAL': 'MEDICAL',
      'code.OTHER': 'OTHER',
      'code.CITIZEN_APP': 'CITIZEN APP',
      'code.IOT_BUTTON': 'IOT BUTTON',
    },
    'sw': {
      'app.title': 'DASHIBODI YA USALAMA YA POLISI',
      'app.command': 'DASHIBODI YA USALAMA YA POLISI',
      'app.citizenCommand': 'DASHIBODI YA USALAMA',
      'app.policeCommand': 'DASHIBODI YA KIUSALAMA YA POLISI',
      'app.subtitle': '',
      'app.router': 'Ripoti',
      'app.secureRouter': 'Ripoti Salama',
      'app.dispatch': 'Mpokeaji wa Polisi',
      'settings.language': 'Lugha',
      'settings.english': 'Kiingereza',
      'settings.swahili': 'Kiswahili',
      'settings.appearance': 'Mwonekano',
      'settings.dark': 'Mandhari meusi',
      'settings.light': 'Mandhari meupe',
      'login.restricted': 'Operesheni zenye ulinzi',
      'login.title': 'INGIA KITUO CHA POLISI',
      'login.instructions':
          'Tumia jina la mtumiaji na nenosiri ulilopewa kwenye taarifa yako ya polisi na msimamizi wa mfumo.',
      'login.username': 'Jina la mtumiaji la afisa',
      'login.password': 'Nenosiri salama',
      'login.submit': 'ANZISHA KIKAO SALAMA',
      'error.invalidPoliceCredentials':
          'Jina la mtumiaji au nenosiri la polisi si sahihi.',
      'error.enterCredentials': 'Weka jina la mtumiaji na nenosiri.',
      'error.session': 'Imeshindikana kuanzisha kikao cha polisi.',
      'error.location': 'Eneo halipatikani.',
      'router.districtStatus': 'HALI YA WILAYA: VIKOSI 5 VIKO HEWANI',
      'router.riskZones': 'MAENEO {count} HATARISHI',
      'router.deviceReports': 'RIPOTI {count} KUTOKA KIFAA HIKI',
      'router.useLocation': 'TUMIA ENEO LANGU',
      'router.refresh': 'Onyesha upya taarifa za wilaya',
      'router.map': 'Ramani ya Hatari kwa Umma',
      'router.mapDetail':
          'Angalia tu maeneo ya hatari ya juu na chini kutoka kituo',
      'router.tapMap':
          'KUANGALIA TU - SOGEZA AU KUZA RAMANI KUONA MAENEO HATARISHI',
      'router.selectedTarget': 'Eneo Lililochaguliwa',
      'router.currentLocation': 'Eneo la Sasa la Ripoti',
      'router.activeZones': 'MAENEO {count} HAI',
      'router.title': 'Ripoti Salama',
      'router.reportTitle': 'Ripoti tishio au mazingira hatarishi',
      'router.instructions':
          'Weka taarifa za tukio la usafiri linalozingatia jinsia au hatari ya usafiri ili kusaidia kupeleka vikosi haraka.',
      'router.incidentType': 'Aina ya tukio',
      'router.priority': 'Kipaumbele cha uchunguzi',
      'router.locationDetails': 'Eneo na maelezo',
      'router.safeEscort': 'Ombi la Kusindikizwa Salama',
      'router.emergencySos': 'Dharura ya SOS',
      'router.harassment': 'Ripoti ya Unyanyasaji',
      'router.stalking': 'Hofu za Kufuatiliwa',
      'router.medical': 'Msaada wa Matibabu',
      'router.brokenStreetlights': 'Taa za Barabarani Zilizoharibika',
      'router.location': 'Eneo maalum',
      'router.locationHint': 'Njia C, Kampasi ya Sayansi ya Chuo Kikuu',
      'router.notes': 'Maelezo ya kina',
      'router.notesHint': 'Weka lebo za tukio au maelezo ya operesheni',
      'router.phone': 'Namba salama ya kupigiwa (si lazima)',
      'router.cancel': 'GHAIRI',
      'router.submit': 'TUMA FOMU',
      'router.coordinates': 'Viratibu vilivyojazwa',
      'router.activeIncident': 'Tukio linaloendelea',
      'router.reportStatus': 'Hali ya Ripoti Zako',
      'router.reportStatusHelp':
          'Mabadiliko kutoka kituo yataonekana hapa moja kwa moja.',
      'router.refreshReportStatus': 'Onyesha upya hali ya ripoti',
      'router.lastUpdated': 'Imesasishwa {time}',
      'router.statusReported': 'Ripoti imepokelewa na inasubiri kukubaliwa.',
      'router.statusAcknowledged': 'Mpokeaji wa polisi amekubali ripoti yako.',
      'router.statusDispatched': 'Kikosi cha mwitikio kimetumwa.',
      'router.statusResolved':
          'Mpokeaji wa polisi ametatua na kufunga ripoti hii.',
      'router.statusFalseAlarm':
          'Mpokeaji wa polisi amefunga ripoti hii kama tahadhari isiyo sahihi.',
      'map.zoomIn': 'Kuza ramani',
      'map.zoomOut': 'Punguza ramani',
      'dispatch.liveFeed': 'MATUKIO YA SASA',
      'dispatch.history': 'KUMBUKUMBU',
      'dispatch.analytics': 'UCHAMBUZI',
      'dispatch.pendingSos': 'SOS {count} ZINASUBIRI',
      'dispatch.hotspots': 'MAENEO {count} HATARISHI',
      'dispatch.stable': 'HALI YA MFUMO: IMARA',
      'dispatch.offline': 'MFUMO HAUPO HEWANI',
      'dispatch.refresh': 'Onyesha upya taarifa za mpokeaji wa polisi',
      'dispatch.logout': 'Maliza kikao cha polisi',
      'dispatch.officer': 'AFISA',
      'dispatch.noBadge': 'HAKUNA NAMBA YA BEJI',
      'dispatch.unassignedStation': 'HAJAWEKWA KITUO',
      'dispatch.incidentFeed': 'Matukio Yanayoendelea',
      'dispatch.priorityQueue': 'Foleni ya vipaumbele',
      'dispatch.all': 'YOTE',
      'dispatch.severe': 'MAKUBWA',
      'dispatch.pending': 'YANASUBIRI',
      'dispatch.closed': 'YAMEFUNGWA',
      'dispatch.noIncidents': 'Hakuna tukio linalolingana na kichujio hiki.',
      'dispatch.examine': 'CHUNGUZA  →',
      'dispatch.iotButtonAlert': 'Tahadhari ya Kitufe cha IoT',
      'dispatch.iotPanicButton': 'Kitufe cha hatari cha IoT',
      'dispatch.source': 'Chanzo',
      'dispatch.device': 'Kifaa',
      'dispatch.unknownDevice': 'Kifaa hakijulikani',
      'dispatch.pressedAt': 'Ilibonyezwa saa',
      'dispatch.reportedAt': 'Iliripotiwa saa',
      'dispatch.resolutionAudit': 'UKAGUZI WA UTATUZI WA CENTRAL',
      'dispatch.solvedBy': 'Imetatuliwa na',
      'dispatch.solvedByStation': 'Kituo cha afisa',
      'dispatch.solvedAt': 'Imetatuliwa saa',
      'dispatch.operationsMap': 'Ramani ya Operesheni',
      'dispatch.responseTelemetry': 'Taarifa za mwitikio wa sasa',
      'dispatch.patrolAssets': 'VIKOSI DORIA',
      'dispatch.dangerAlerts': 'TAHADHARI ZA HATARI',
      'dispatch.riskHigh': 'HATARI JUU',
      'dispatch.riskLow': 'HATARI CHINI',
      'dispatch.patrolAsset': 'KIKOSI DORIA',
      'dispatch.escort': 'USINDIKIZAJI',
      'dispatch.zoomIn': 'Kuza ramani',
      'dispatch.zoomOut': 'Punguza ramani',
      'dispatch.centerGrid': 'Rudisha katikati',
      'dispatch.threatIntelligence': 'Taarifa za Vitisho',
      'dispatch.hotspotManagement': 'Usimamizi wa maeneo hatarishi',
      'dispatch.mapLayerManagement':
          'Usimamizi wa ramani wa mpokeaji wa polisi',
      'dispatch.closeDrawing': 'FUNGA HALI YA KUCHORA',
      'dispatch.drawHotspot': '+ CHORA ENEO HATARISHI',
      'dispatch.hotspotHelp': 'Jinsi ya kuweka eneo hatarishi',
      'dispatch.hotspotInstructions':
          'Gusa ramani ya operesheni, kisha unda au sasisha eneo la hatari ya chini/juu au kikosi doria.',
      'dispatch.noHotspots':
          'Hakuna maeneo hatarishi yaliyosajiliwa katika wilaya hii.',
      'dispatch.registeredHotspots': 'Maeneo Hatarishi Yaliyosajiliwa',
      'dispatch.active': '{count} HAI',
      'dispatch.radiusRisk': 'Kipenyo {radius}m · hatari {risk}',
      'dispatch.automaticZone': 'OTOMATIKI · RIPOTI {count}',
      'dispatch.manualZone': 'LIMEWEKWA NA POLISI',
      'dispatch.drawingActive': 'Hali ya Kuchora Imewashwa',
      'dispatch.tapCoordinates': 'Gusa ramani ili kujaza viratibu.',
      'dispatch.zoneTitle': 'Jina la eneo',
      'dispatch.latitude': 'Latitudo',
      'dispatch.longitude': 'Longitudo',
      'dispatch.radius': 'Kipenyo kwa mita',
      'dispatch.riskLevel': 'Kiwango cha hatari',
      'dispatch.operatorNotes': 'Maelezo ya opereta',
      'dispatch.registerHotspot': 'SAJILI ENEO HATARISHI',
      'dispatch.invalidCoordinates': 'Weka viratibu na kipenyo sahihi.',
      'dispatch.unsafeZone': 'Eneo hatarishi',
      'dispatch.setLowRisk': 'Weka hatari chini',
      'dispatch.setHighRisk': 'Weka hatari juu',
      'dispatch.deactivate': 'Zima',
      'dispatch.noPatrolAssets': 'Hakuna vikosi doria hai katika wilaya hii.',
      'dispatch.registeredPatrolAssets': 'Vikosi Doria Vilivyosajiliwa',
      'dispatch.moveHere': 'HAMISHA HAPA',
      'dispatch.patrolAssetManagement': 'Sajili Kikosi Doria',
      'dispatch.patrolAssetInstructions':
          'Gusa ramani ya operesheni, kisha sajili kikosi doria katika eneo hilo.',
      'dispatch.assetName': 'Jina la kikosi doria',
      'dispatch.assetStatus': 'Hali ya kikosi doria',
      'dispatch.registerPatrolAsset': 'SAJILI KIKOSI DORIA',
      'dispatch.invalidPatrolAsset':
          'Weka jina la kikosi na uchague eneo kwenye ramani.',
      'dispatch.safetyTips': 'Vidokezo vya Usalama vya Simu',
      'dispatch.safetyTipsHelp':
          'Polisi Central wanaweza kuchapisha na kusasisha mwongozo unaoonekana kwenye programu ya simu.',
      'dispatch.tipTitle': 'Kichwa cha kidokezo',
      'dispatch.tipBody': 'Mwongozo wa usalama',
      'dispatch.tipCategory': 'Kategoria (si lazima)',
      'dispatch.tipOrder': 'Mpangilio',
      'dispatch.publishTip': 'CHAPISHA KIDOKEZO',
      'dispatch.updateTip': 'SASISHA KIDOKEZO',
      'dispatch.cancelEdit': 'Ghairi kuhariri',
      'dispatch.noSafetyTips': 'Hakuna vidokezo hai vya usalama vya simu.',
      'dispatch.invalidSafetyTip': 'Weka kichwa, mwongozo na mpangilio sahihi.',
      'dispatch.edit': 'HARIRI',
      'incident.sos': 'Tahadhari ya Dharura ya SOS',
      'incident.harassment': 'Ripoti ya Unyanyasaji',
      'incident.stalking': 'Hofu za Kufuatiliwa',
      'incident.medical': 'Msaada wa Matibabu',
      'incident.escort': 'Ombi la Kusindikizwa Salama',
      'incident.brokenStreetlights': 'Taa za Barabarani Zilizoharibika',
      'code.LOW': 'CHINI',
      'code.MEDIUM': 'WASTANI',
      'code.HIGH': 'JUU',
      'code.CRITICAL': 'HATARI SANA',
      'code.AVAILABLE': 'KIPO TAYARI',
      'code.DEPLOYED': 'KIMETUMWA',
      'code.OFFLINE': 'HAKIPO HEWANI',
      'code.REPORTED': 'IMERIPOTIWA',
      'code.ACKNOWLEDGED': 'IMEPOKELEWA',
      'code.DISPATCHED': 'KIKOSI KIMETUMWA',
      'code.RESOLVED': 'IMETATULIWA',
      'code.FALSE_ALARM': 'TAHADHARI ISIYO SAHIHI',
      'code.SOS': 'SOS',
      'code.HARASSMENT': 'UNYANYASAJI',
      'code.STALKING': 'KUFUATILIWA',
      'code.MEDICAL': 'MATIBABU',
      'code.OTHER': 'NYINGINE',
      'code.CITIZEN_APP': 'APP YA RAIA',
      'code.IOT_BUTTON': 'IOT BUTTON',
    },
  };
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => AppLocalizations.supportedLocales.any(
    (supported) => supported.languageCode == locale.languageCode,
  );

  @override
  Future<AppLocalizations> load(Locale locale) =>
      SynchronousFuture(AppLocalizations(locale));

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

extension AppLocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
