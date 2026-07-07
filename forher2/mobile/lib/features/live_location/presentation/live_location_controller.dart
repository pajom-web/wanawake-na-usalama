import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../data/live_location_socket.dart';
import '../data/live_tracking_repository.dart';
import '../domain/live_location_state.dart';

final liveLocationControllerProvider =
    AsyncNotifierProvider<LiveLocationController, LiveLocationState>(
  LiveLocationController.new,
);

class LiveLocationController extends AsyncNotifier<LiveLocationState> {
  StreamSubscription<Position>? _positionSubscription;

  @override
  Future<LiveLocationState> build() async {
    ref.onDispose(() {
      _positionSubscription?.cancel();
      ref.read(liveLocationSocketProvider).close();
    });
    return const LiveLocationState.idle();
  }

  Future<void> toggleTracking() async {
    final current = state.valueOrNull;
    if (current?.active == true) {
      await teardown();
      return;
    }

    state = const AsyncLoading();
    try {
      await _ensureLocationPermission();
      final session =
          await ref.read(liveTrackingRepositoryProvider).createSession();
      await ref.read(liveLocationSocketProvider).connect(session.sessionToken);
      final position = await Geolocator.getCurrentPosition();
      ref
          .read(liveLocationSocketProvider)
          .sendLocation(LatLng(position.latitude, position.longitude));
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((position) {
        ref
            .read(liveLocationSocketProvider)
            .sendLocation(LatLng(position.latitude, position.longitude));
      });
      state = AsyncData(
        LiveLocationState(
          active: true,
          sessionId: session.id,
          sessionToken: session.sessionToken,
        ),
      );
    } catch (error, stackTrace) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      await ref.read(liveLocationSocketProvider).close();
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> teardown() async {
    final current = state.valueOrNull;
    ref.read(liveLocationSocketProvider).sendEnd();
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    await ref.read(liveLocationSocketProvider).close();
    if (current?.sessionId != null) {
      try {
        await ref
            .read(liveTrackingRepositoryProvider)
            .revokeSession(current!.sessionId!);
      } catch (_) {
        // Logout also revokes active sessions server-side; avoid trapping users.
      }
    }
    state = const AsyncData(LiveLocationState.idle());
  }

  Future<void> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Location services are disabled.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission denied.');
    }
  }
}
