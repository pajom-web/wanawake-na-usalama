import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../models/hotspot.dart';
import '../models/incident.dart';
import '../models/patrol_asset.dart';
import '../theme/tactical_theme.dart';

class SafetyMap extends StatefulWidget {
  const SafetyMap({
    super.key,
    required this.center,
    this.hotspots = const [],
    this.incidents = const [],
    this.patrolAssets = const [],
    this.onTap,
    this.interactive = true,
    this.showCenterMarker = true,
    this.showZoomControls = false,
    this.showBaseMap = true,
    this.focusRevision = 0,
    this.height,
  });

  final LatLng center;
  final List<Hotspot> hotspots;
  final List<Incident> incidents;
  final List<PatrolAsset> patrolAssets;
  final void Function(LatLng point)? onTap;
  final bool interactive;
  final bool showCenterMarker;
  final bool showZoomControls;
  final bool showBaseMap;
  final int focusRevision;
  final double? height;

  @override
  State<SafetyMap> createState() => _SafetyMapState();
}

class _SafetyMapState extends State<SafetyMap> {
  final MapController _mapController = MapController();

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SafetyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final centerChanged =
        oldWidget.center.latitude != widget.center.latitude ||
        oldWidget.center.longitude != widget.center.longitude;
    final focusRequested = oldWidget.focusRevision != widget.focusRevision;
    if (centerChanged || focusRequested) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _mapController.move(widget.center, _mapController.camera.zoom);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final map = FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: widget.center,
        initialZoom: 13,
        minZoom: 3,
        maxZoom: 18,
        onTap: widget.onTap == null ? null : (_, point) => widget.onTap!(point),
        interactionOptions: InteractionOptions(
          flags: widget.interactive
              ? InteractiveFlag.all
              : InteractiveFlag.none,
        ),
      ),
      children: [
        if (widget.showBaseMap)
          TileLayer(
            urlTemplate: Theme.of(context).brightness == Brightness.dark
                ? 'https://basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                : 'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.local.safety_mobility',
          ),
        PolygonLayer(polygons: _hotspotPolygons()),
        MarkerLayer(markers: _hotspotMarkers()),
        MarkerLayer(markers: _incidentMarkers()),
        MarkerLayer(markers: _patrolAssetMarkers()),
        if (widget.showCenterMarker)
          MarkerLayer(
            markers: [
              Marker(
                point: widget.center,
                width: 34,
                height: 34,
                child: Icon(
                  Icons.my_location,
                  color: TacticalColors.active,
                  size: 28,
                ),
              ),
            ],
          ),
      ],
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            Positioned.fill(child: map),
            if (widget.showZoomControls)
              Positioned(
                right: 12,
                top: 62,
                child: _ZoomControls(
                  onZoomIn: () => _zoomBy(1),
                  onZoomOut: () => _zoomBy(-1),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<Polygon> _hotspotPolygons() {
    return widget.hotspots
        .where((hotspot) => hotspot.active)
        .map(
          (hotspot) => Polygon(
            points: _circlePoints(
              hotspot.centerLatitude,
              hotspot.centerLongitude,
              hotspot.radiusMeters.toDouble(),
            ),
            color: _riskColor(hotspot.riskLevel).withValues(alpha: 0.24),
            borderColor: _riskColor(hotspot.riskLevel).withValues(alpha: 0.85),
            borderStrokeWidth: 2,
          ),
        )
        .toList();
  }

  List<Marker> _patrolAssetMarkers() {
    return widget.patrolAssets
        .where((asset) => asset.active)
        .map(
          (asset) => Marker(
            point: LatLng(asset.latitude, asset.longitude),
            width: 42,
            height: 42,
            child: Tooltip(
              message: '${asset.name} - ${asset.status}',
              child: Container(
                decoration: BoxDecoration(
                  color: _patrolAssetColor(asset.status),
                  border: Border.all(color: TacticalColors.text, width: 2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.local_police_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  List<Marker> _hotspotMarkers() {
    return widget.hotspots
        .where((hotspot) => hotspot.active)
        .map(
          (hotspot) => Marker(
            point: LatLng(hotspot.centerLatitude, hotspot.centerLongitude),
            width: 38,
            height: 38,
            child: Tooltip(
              message: hotspot.incidentCount > 0
                  ? '${hotspot.title} - ${hotspot.riskLevel} risk '
                        '(${hotspot.incidentCount} reports)'
                  : '${hotspot.title} - ${hotspot.riskLevel} risk',
              child: Container(
                decoration: BoxDecoration(
                  color: _riskColor(hotspot.riskLevel),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Icon(
                  hotspot.riskLevel == 'HIGH'
                      ? Icons.warning_amber_rounded
                      : Icons.shield_outlined,
                  color: Colors.white,
                  size: 21,
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  List<Marker> _incidentMarkers() {
    return widget.incidents
        .where(
          (incident) =>
              incident.status != 'RESOLVED' && incident.status != 'FALSE_ALARM',
        )
        .map(
          (incident) => Marker(
            point: LatLng(incident.latitude, incident.longitude),
            width: 44,
            height: 44,
            child: Tooltip(
              message:
                  '${incident.isIotButton ? 'IoT button' : incident.category} '
                  '- ${incident.severity}',
              child: Container(
                decoration: BoxDecoration(
                  color: TacticalColors.critical,
                  border: Border.all(color: Colors.white, width: 2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: TacticalColors.critical.withValues(alpha: 0.38),
                      blurRadius: 14,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  incident.isIotButton
                      ? Icons.sensors
                      : Icons.emergency_share_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        )
        .toList();
  }

  List<LatLng> _circlePoints(double lat, double lon, double radiusMeters) {
    const earthRadius = 6378137.0;
    final distance = radiusMeters / earthRadius;
    final latRad = _degreesToRadians(lat);
    final lonRad = _degreesToRadians(lon);
    final points = <LatLng>[];

    for (var i = 0; i <= 72; i++) {
      final bearing = 2 * math.pi * i / 72;
      final pointLat = math.asin(
        math.sin(latRad) * math.cos(distance) +
            math.cos(latRad) * math.sin(distance) * math.cos(bearing),
      );
      final pointLon =
          lonRad +
          math.atan2(
            math.sin(bearing) * math.sin(distance) * math.cos(latRad),
            math.cos(distance) - math.sin(latRad) * math.sin(pointLat),
          );
      points.add(
        LatLng(_radiansToDegrees(pointLat), _radiansToDegrees(pointLon)),
      );
    }

    return points;
  }

  double _degreesToRadians(double degrees) => degrees * math.pi / 180;
  double _radiansToDegrees(double radians) => radians * 180 / math.pi;

  Color _riskColor(String riskLevel) {
    switch (riskLevel) {
      case 'HIGH':
        return TacticalColors.critical;
      default:
        return TacticalColors.low;
    }
  }

  Color _patrolAssetColor(String status) {
    switch (status) {
      case 'DEPLOYED':
        return TacticalColors.pending;
      case 'OFFLINE':
        return TacticalColors.textMuted;
      default:
        return TacticalColors.active;
    }
  }

  void _zoomBy(double delta) {
    final camera = _mapController.camera;
    _mapController.move(
      camera.center,
      (camera.zoom + delta).clamp(3.0, 18.0).toDouble(),
    );
  }
}

class _ZoomControls extends StatelessWidget {
  const _ZoomControls({required this.onZoomIn, required this.onZoomOut});

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TacticalColors.background.withValues(alpha: 0.92),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: TacticalColors.borderStrong),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: onZoomIn,
            tooltip: context.l10n.t('map.zoomIn'),
            icon: Icon(Icons.add),
          ),
          Divider(height: 1),
          IconButton(
            onPressed: onZoomOut,
            tooltip: context.l10n.t('map.zoomOut'),
            icon: Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
