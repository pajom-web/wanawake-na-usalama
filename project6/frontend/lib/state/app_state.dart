import 'dart:async';
import 'dart:js_interop';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:web/web.dart' as web;

import '../config/app_config.dart';
import '../models/hotspot.dart';
import '../models/incident.dart';
import '../models/patrol_asset.dart';
import '../models/safety_tip.dart';
import '../services/api_client.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';

const defaultMapCenter = LatLng(-6.7924, 39.2083);

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient();
  ref.onDispose(() {
    client.close();
  });
  return client;
});

final storageServiceProvider = Provider<StorageService>(
  (ref) => StorageService(),
);

final citizenControllerProvider =
    StateNotifierProvider<CitizenController, CitizenState>((ref) {
      final controller = CitizenController(
        ref.read(apiClientProvider),
        ref.read(storageServiceProvider),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });

final policeControllerProvider =
    StateNotifierProvider<PoliceController, PoliceState>((ref) {
      final controller = PoliceController(ref.read(apiClientProvider));
      ref.onDispose(controller.dispose);
      return controller;
    });

class CitizenState {
  const CitizenState({
    required this.anonymousToken,
    required this.selectedLocation,
    required this.hotspots,
    required this.incidents,
    required this.isLoading,
    required this.isReporting,
    this.error,
    this.lastIncident,
  });

  final String anonymousToken;
  final LatLng selectedLocation;
  final List<Hotspot> hotspots;
  final List<Incident> incidents;
  final bool isLoading;
  final bool isReporting;
  final String? error;
  final Incident? lastIncident;

  CitizenState copyWith({
    String? anonymousToken,
    LatLng? selectedLocation,
    List<Hotspot>? hotspots,
    List<Incident>? incidents,
    bool? isLoading,
    bool? isReporting,
    String? error,
    bool clearError = false,
    Incident? lastIncident,
  }) {
    return CitizenState(
      anonymousToken: anonymousToken ?? this.anonymousToken,
      selectedLocation: selectedLocation ?? this.selectedLocation,
      hotspots: hotspots ?? this.hotspots,
      incidents: incidents ?? this.incidents,
      isLoading: isLoading ?? this.isLoading,
      isReporting: isReporting ?? this.isReporting,
      error: clearError ? null : error ?? this.error,
      lastIncident: lastIncident ?? this.lastIncident,
    );
  }
}

class CitizenController extends StateNotifier<CitizenState> {
  CitizenController(this._api, this._storage)
    : super(
        CitizenState(
          anonymousToken: _storage.getOrCreateAnonymousToken(),
          selectedLocation: defaultMapCenter,
          hotspots: const [],
          incidents: const [],
          isLoading: true,
          isReporting: false,
        ),
      ) {
    Future.microtask(refresh);
    _connectHotspotSocket();
    _statusRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(refreshIncidentStatuses());
    });
  }

  final ApiClient _api;
  final StorageService _storage;
  JsonWebSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;
  Timer? _statusRefreshTimer;
  bool _isRefreshingStatuses = false;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        _api.fetchPublicHotspots(),
        _api.fetchCitizenIncidents(state.anonymousToken),
      ]);
      state = state.copyWith(
        isLoading: false,
        hotspots: results[0] as List<Hotspot>,
        incidents: results[1] as List<Incident>,
        lastIncident: _preferredIncident(results[1] as List<Incident>),
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> useBrowserLocation() async {
    try {
      final location = await _readBrowserLocation();
      state = state.copyWith(selectedLocation: location, clearError: true);
    } catch (error) {
      state = state.copyWith(error: 'Location unavailable: $error');
    }
  }

  Future<void> refreshIncidentStatuses() async {
    if (_isRefreshingStatuses) {
      return;
    }
    _isRefreshingStatuses = true;
    try {
      final incidents = await _api.fetchCitizenIncidents(state.anonymousToken);
      state = state.copyWith(
        incidents: incidents,
        lastIncident: _preferredIncident(incidents),
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(error: error.toString());
    } finally {
      _isRefreshingStatuses = false;
    }
  }

  Future<void> sendSos({
    String category = 'SOS',
    String severity = 'CRITICAL',
    String description = '',
    String reporterPhone = '',
  }) async {
    state = state.copyWith(isReporting: true, clearError: true);
    try {
      final location = state.selectedLocation;
      final incident = await _api.createIncident(
        anonymousToken: state.anonymousToken,
        latitude: location.latitude,
        longitude: location.longitude,
        category: category,
        severity: severity,
        description: description,
        reporterPhone: reporterPhone,
      );
      final token = incident.anonymousToken ?? state.anonymousToken;
      _storage.setAnonymousToken(token);
      state = state.copyWith(
        anonymousToken: token,
        selectedLocation: location,
        isReporting: false,
        lastIncident: incident,
        incidents: [incident, ...state.incidents],
      );
    } catch (error) {
      state = state.copyWith(isReporting: false, error: error.toString());
    }
  }

  Future<LatLng> _readBrowserLocation() async {
    final completer = Completer<LatLng>();
    web.window.navigator.geolocation.getCurrentPosition(
      ((web.GeolocationPosition position) {
        final coords = position.coords;
        completer.complete(LatLng(coords.latitude, coords.longitude));
      }).toJS,
      ((web.GeolocationPositionError error) {
        completer.completeError(error.message);
      }).toJS,
      web.PositionOptions(
        enableHighAccuracy: true,
        timeout: 8000,
        maximumAge: 15000,
      ),
    );
    return completer.future.timeout(const Duration(seconds: 9));
  }

  void _connectHotspotSocket() {
    try {
      _socket = JsonWebSocket(AppConfig.citizenHotspotsWsUrl);
      _socketSubscription = _socket!.stream.listen((message) {
        final event = message['event'] as String?;
        if (event != null && event.startsWith('hotspot.')) {
          refresh();
        }
      });
    } catch (error) {
      state = state.copyWith(error: 'Hotspot socket unavailable: $error');
    }
  }

  Incident? _preferredIncident(List<Incident> incidents) {
    if (incidents.isEmpty) {
      return null;
    }
    final preferredId = state.lastIncident?.id;
    if (preferredId != null) {
      for (final incident in incidents) {
        if (incident.id == preferredId) {
          return incident;
        }
      }
    }
    return incidents.first;
  }

  @override
  void dispose() {
    _statusRefreshTimer?.cancel();
    _socketSubscription?.cancel();
    _socket?.close();
    super.dispose();
  }
}

class PoliceState {
  const PoliceState({
    required this.incidents,
    required this.hotspots,
    required this.patrolAssets,
    required this.safetyTips,
    required this.isLoading,
    required this.socketConnected,
    this.user,
    this.error,
    this.lastAlert,
  });

  final Map<String, dynamic>? user;
  final List<Incident> incidents;
  final List<Hotspot> hotspots;
  final List<PatrolAsset> patrolAssets;
  final List<SafetyTip> safetyTips;
  final bool isLoading;
  final bool socketConnected;
  final String? error;
  final Incident? lastAlert;

  bool get isAuthenticated => user != null;

  PoliceState copyWith({
    Map<String, dynamic>? user,
    bool clearUser = false,
    List<Incident>? incidents,
    List<Hotspot>? hotspots,
    List<PatrolAsset>? patrolAssets,
    List<SafetyTip>? safetyTips,
    bool? isLoading,
    bool? socketConnected,
    String? error,
    bool clearError = false,
    Incident? lastAlert,
  }) {
    return PoliceState(
      user: clearUser ? null : user ?? this.user,
      incidents: incidents ?? this.incidents,
      hotspots: hotspots ?? this.hotspots,
      patrolAssets: patrolAssets ?? this.patrolAssets,
      safetyTips: safetyTips ?? this.safetyTips,
      isLoading: isLoading ?? this.isLoading,
      socketConnected: socketConnected ?? this.socketConnected,
      error: clearError ? null : error ?? this.error,
      lastAlert: lastAlert ?? this.lastAlert,
    );
  }
}

class PoliceController extends StateNotifier<PoliceState> {
  PoliceController(this._api)
    : super(
        const PoliceState(
          incidents: [],
          hotspots: [],
          patrolAssets: [],
          safetyTips: [],
          isLoading: true,
          socketConnected: false,
        ),
      ) {
    Future.microtask(bootstrap);
  }

  final ApiClient _api;
  JsonWebSocket? _socket;
  StreamSubscription<Map<String, dynamic>>? _socketSubscription;

  Future<void> bootstrap() async {
    try {
      final user = await _api.fetchPoliceMe();
      state = state.copyWith(user: user, isLoading: false, clearError: true);
      await refresh();
      _connectSocket();
    } catch (_) {
      state = state.copyWith(isLoading: false, clearUser: true);
    }
  }

  Future<void> login(String username, String password) async {
    if (username.isEmpty || password.isEmpty) {
      state = state.copyWith(
        isLoading: false,
        clearUser: true,
        error: 'Enter both username and password.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final loginUser = await _api.loginPolice(
        username: username,
        password: password,
      );
      final user = await _api.fetchPoliceMe();
      if (loginUser['id'] != user['id']) {
        throw const ApiException('Unable to establish the police session.');
      }
      state = state.copyWith(user: user, isLoading: false);
      await refresh();
      _connectSocket();
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        clearUser: true,
        error: error.toString(),
      );
    }
  }

  Future<void> logout() async {
    await _api.logoutPolice();
    await _socketSubscription?.cancel();
    await _socket?.close();
    state = const PoliceState(
      incidents: [],
      hotspots: [],
      patrolAssets: [],
      safetyTips: [],
      isLoading: false,
      socketConnected: false,
    );
  }

  Future<void> refresh() async {
    if (!state.isAuthenticated) {
      return;
    }
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final canManageSafetyTips = state.user?['can_manage_safety_tips'] == true;
      final requests = <Future<Object>>[
        _api.fetchPoliceIncidents(),
        _api.fetchPoliceHotspots(),
        _api.fetchPolicePatrolAssets(),
        if (canManageSafetyTips) _api.fetchPoliceSafetyTips(),
      ];
      final results = await Future.wait(requests);
      state = state.copyWith(
        incidents: results[0] as List<Incident>,
        hotspots: results[1] as List<Hotspot>,
        patrolAssets: results[2] as List<PatrolAsset>,
        safetyTips: canManageSafetyTips
            ? results[3] as List<SafetyTip>
            : const [],
        isLoading: false,
      );
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<void> updateIncidentStatus(String id, String status) async {
    try {
      final updated = await _api.updateIncidentStatus(id, status);
      _upsertIncident(updated, alert: false);
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> createHotspot(Hotspot hotspot) async {
    try {
      final created = await _api.createHotspot(hotspot);
      _upsertHotspot(created);
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> setHotspotRisk(Hotspot hotspot, String riskLevel) async {
    try {
      final updated = await _api.updateHotspotRisk(hotspot.id, riskLevel);
      _upsertHotspot(updated);
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> deactivateHotspot(Hotspot hotspot) async {
    try {
      await _api.deactivateHotspot(hotspot.id);
      state = state.copyWith(
        hotspots: state.hotspots
            .where((item) => item.id != hotspot.id)
            .toList(),
      );
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> createPatrolAsset(PatrolAsset asset) async {
    try {
      final created = await _api.createPatrolAsset(asset);
      _upsertPatrolAsset(created);
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> movePatrolAsset(PatrolAsset asset, LatLng location) async {
    try {
      final updated = await _api.updatePatrolAsset(
        asset.id,
        latitude: location.latitude,
        longitude: location.longitude,
        status: 'DEPLOYED',
      );
      _upsertPatrolAsset(updated);
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> deactivatePatrolAsset(PatrolAsset asset) async {
    try {
      await _api.deactivatePatrolAsset(asset.id);
      state = state.copyWith(
        patrolAssets: state.patrolAssets
            .where((item) => item.id != asset.id)
            .toList(),
      );
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> saveSafetyTip(SafetyTip tip) async {
    try {
      final saved = tip.id == 0
          ? await _api.createSafetyTip(tip)
          : await _api.updateSafetyTip(tip);
      _upsertSafetyTip(saved);
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  Future<void> deactivateSafetyTip(SafetyTip tip) async {
    try {
      await _api.deactivateSafetyTip(tip.id);
      state = state.copyWith(
        safetyTips: state.safetyTips
            .where((item) => item.id != tip.id)
            .toList(),
      );
    } catch (error) {
      state = state.copyWith(error: error.toString());
    }
  }

  void _connectSocket() {
    _socketSubscription?.cancel();
    _socket?.close();
    try {
      _socket = JsonWebSocket(AppConfig.policeAlertsWsUrl);
      _socketSubscription = _socket!.stream.listen(
        (message) {
          final event = message['event'] as String?;
          if (event == 'connected') {
            state = state.copyWith(socketConnected: true);
          }
          if (event == 'incident.created' || event == 'incident.updated') {
            _upsertIncident(
              Incident.fromJson(message['incident'] as Map<String, dynamic>),
              alert: event == 'incident.created',
            );
          }
          if (event != null && event.startsWith('hotspot.')) {
            final hotspot = Hotspot.fromJson(
              message['hotspot'] as Map<String, dynamic>,
            );
            if (event == 'hotspot.deactivated') {
              state = state.copyWith(
                hotspots: state.hotspots
                    .where((item) => item.id != hotspot.id)
                    .toList(),
              );
            } else {
              _upsertHotspot(hotspot);
            }
          }
          if (event != null && event.startsWith('patrol_asset.')) {
            final asset = PatrolAsset.fromJson(
              message['patrol_asset'] as Map<String, dynamic>,
            );
            if (event == 'patrol_asset.deactivated') {
              state = state.copyWith(
                patrolAssets: state.patrolAssets
                    .where((item) => item.id != asset.id)
                    .toList(),
              );
            } else {
              _upsertPatrolAsset(asset);
            }
          }
        },
        onError: (error) {
          state = state.copyWith(
            socketConnected: false,
            error: error.toString(),
          );
        },
        onDone: () {
          state = state.copyWith(socketConnected: false);
        },
      );
    } catch (error) {
      state = state.copyWith(socketConnected: false, error: error.toString());
    }
  }

  void _upsertIncident(Incident incident, {required bool alert}) {
    Incident? existingIncident;
    for (final item in state.incidents) {
      if (item.id == incident.id) {
        existingIncident = item;
        break;
      }
    }
    final mergedIncident =
        incident.status == 'RESOLVED' &&
            !incident.hasResolutionDetails &&
            existingIncident != null &&
            existingIncident.hasResolutionDetails
        ? incident.copyWith(
            solvedByName: existingIncident.solvedByName,
            solvedByBadgeNumber: existingIncident.solvedByBadgeNumber,
            solvedByStation: existingIncident.solvedByStation,
            solvedAt: existingIncident.solvedAt,
          )
        : incident;
    final withoutExisting = state.incidents
        .where((item) => item.id != incident.id)
        .toList();
    state = state.copyWith(
      incidents: [mergedIncident, ...withoutExisting],
      lastAlert: alert ? mergedIncident : state.lastAlert,
    );
  }

  void _upsertHotspot(Hotspot hotspot) {
    final withoutExisting = state.hotspots
        .where((item) => item.id != hotspot.id)
        .toList();
    state = state.copyWith(hotspots: [hotspot, ...withoutExisting]);
  }

  void _upsertPatrolAsset(PatrolAsset asset) {
    final withoutExisting = state.patrolAssets
        .where((item) => item.id != asset.id)
        .toList();
    state = state.copyWith(patrolAssets: [asset, ...withoutExisting]);
  }

  void _upsertSafetyTip(SafetyTip tip) {
    final tips = [tip, ...state.safetyTips.where((item) => item.id != tip.id)]
      ..sort((a, b) {
        final order = a.displayOrder.compareTo(b.displayOrder);
        return order != 0 ? order : b.publishedAt.compareTo(a.publishedAt);
      });
    state = state.copyWith(safetyTips: tips);
  }

  @override
  void dispose() {
    _socketSubscription?.cancel();
    _socket?.close();
    super.dispose();
  }
}
