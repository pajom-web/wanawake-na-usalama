import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/localization/language_toggle_button.dart';
import '../../../core/theme/safety_colors.dart';
import '../../../core/theme/theme_toggle_button.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../live_location/presentation/live_location_controller.dart';
import '../../report/data/incident_repository.dart';
import '../../report/domain/report_submission_status.dart';
import '../../report/presentation/incident_history_sheet.dart';
import '../../report/presentation/report_sheet.dart';
import '../../report/presentation/report_status_controller.dart';
import '../../safety_tips/presentation/safety_tips_sheet.dart';
import 'map_controller.dart';

class SafetyMapScreen extends ConsumerStatefulWidget {
  const SafetyMapScreen({super.key});

  @override
  ConsumerState<SafetyMapScreen> createState() => _SafetyMapScreenState();
}

class _SafetyMapScreenState extends ConsumerState<SafetyMapScreen> {
  final _mapController = MapController();
  LatLng _center = HotspotListController.defaultCenter;

  @override
  Widget build(BuildContext context) {
    final hotspots = ref.watch(hotspotListProvider);
    final live = ref.watch(liveLocationControllerProvider);
    final reportStatus = ref.watch(reportSubmissionStatusProvider);
    final incidentHistory = ref.watch(incidentHistoryProvider);
    final latestReportStatus =
        latestIncidentStatus(incidentHistory.valueOrNull);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 14,
              minZoom: 3,
              maxZoom: 19,
              onPositionChanged: (camera, hasGesture) {
                if (hasGesture) _center = camera.center;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: isDark
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: const ['a', 'b', 'c', 'd'],
                userAgentPackageName: 'com.example.gender_sensitive_safety',
              ),
              hotspots.when(
                data: (items) => CircleLayer<Object>(
                  circles: [
                    for (final hotspot in items.where((item) => item.active))
                      CircleMarker<Object>(
                        point: hotspot.point,
                        radius: hotspot.radiusMeters.toDouble(),
                        useRadiusInMeter: true,
                        color: _hotspotColor(context, hotspot.riskLevel)
                            .withValues(alpha: 0.18),
                        borderColor: _hotspotColor(context, hotspot.riskLevel)
                            .withValues(alpha: 0.75),
                        borderStrokeWidth: 2,
                      ),
                  ],
                ),
                error: (_, __) => const CircleLayer<Object>(
                    circles: <CircleMarker<Object>>[]),
                loading: () => const CircleLayer<Object>(
                    circles: <CircleMarker<Object>>[]),
              ),
              hotspots.when(
                data: (items) => MarkerLayer(
                  markers: [
                    for (final hotspot in items.where((item) => item.active))
                      Marker(
                        point: hotspot.point,
                        width: 54,
                        height: 54,
                        child: Tooltip(
                          message:
                              '${hotspot.title} · ${hotspot.riskLevel} risk · '
                              '${hotspot.incidentCount} reports',
                          child: _IncidentPin(
                            level: hotspot.riskLevel,
                            count: hotspot.incidentCount,
                          ),
                        ),
                      ),
                  ],
                ),
                error: (_, __) => const MarkerLayer(markers: []),
                loading: () => const MarkerLayer(markers: []),
              ),
            ],
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: _StatusPill(
                      liveActive: live.valueOrNull?.active ?? false,
                      reportStatus: reportStatus,
                      latestReportStatus: latestReportStatus,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const LanguageToggleButton(),
                  const SizedBox(width: 8),
                  const ThemeToggleButton(),
                  const SizedBox(width: 8),
                  _RoundAction(
                    icon: Icons.logout,
                    tooltip: l10n.logout,
                    onTap: () async {
                      await ref
                          .read(liveLocationControllerProvider.notifier)
                          .teardown();
                      await ref.read(authControllerProvider.notifier).logout();
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: 118,
            child: _MicroDashboard(
              onReport: () => showReportSheet(context, _center),
              onTips: () => showSafetyTipsSheet(context),
              onHistory: () => showIncidentHistorySheet(context),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _MapBottomSheet(
              center: _center,
              hotspots: hotspots.valueOrNull ?? const [],
              loading: hotspots.isLoading,
              error: hotspots.hasError ? hotspots.error.toString() : null,
              onRefresh: () =>
                  ref.read(hotspotListProvider.notifier).refreshAround(_center),
            ),
          ),
        ],
      ),
    );
  }
}

String? latestIncidentStatus(List<IncidentReportSummary>? incidents) {
  if (incidents == null || incidents.isEmpty) return null;
  return incidents.first.status;
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.liveActive,
    required this.reportStatus,
    this.latestReportStatus,
  });

  final bool liveActive;
  final ReportSubmissionStatus reportStatus;
  final String? latestReportStatus;

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;
    final status = _statusPresentation(colors, context.l10n);

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          Icon(
            status.icon,
            color: status.color,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status.label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.primaryText,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _StatusPresentation _statusPresentation(
    SafetyPalette colors,
    AppLocalizations l10n,
  ) {
    switch (reportStatus.state) {
      case ReportDeliveryState.sending:
        return _StatusPresentation(
          icon: Icons.sync_outlined,
          color: colors.warning,
          label: l10n.sendingReport,
        );
      case ReportDeliveryState.received:
        if (latestReportStatus != null) {
          return _StatusPresentation(
            icon: Icons.track_changes_outlined,
            color: _reportStatusColor(colors, latestReportStatus!),
            label: l10n.reportStatusUpdated(latestReportStatus!),
          );
        }
        return _StatusPresentation(
          icon: Icons.verified_outlined,
          color: colors.safe,
          label: l10n.reportReceived(reportStatus.reportId?.toString()),
        );
      case ReportDeliveryState.failed:
        return _StatusPresentation(
          icon: Icons.error_outline,
          color: colors.warning,
          label: l10n.reportNotReceived,
        );
      case ReportDeliveryState.idle:
        if (latestReportStatus != null) {
          return _StatusPresentation(
            icon: Icons.track_changes_outlined,
            color: _reportStatusColor(colors, latestReportStatus!),
            label: l10n.reportStatusUpdated(latestReportStatus!),
          );
        }
        return _StatusPresentation(
          icon: liveActive
              ? Icons.radio_button_checked
              : Icons.radio_button_unchecked,
          color: liveActive ? colors.safe : colors.secondaryText,
          label: liveActive ? l10n.liveLocationActive : l10n.riskMapReady,
        );
    }
  }
}

Color _reportStatusColor(SafetyPalette colors, String status) {
  return switch (status) {
    'RESOLVED' => colors.safe,
    'FALSE_ALARM' => colors.secondaryText,
    'DISPATCHED' => colors.warning,
    _ => colors.safe,
  };
}

class _StatusPresentation {
  const _StatusPresentation({
    required this.icon,
    required this.color,
    required this.label,
  });

  final IconData icon;
  final Color color;
  final String label;
}

class _MicroDashboard extends StatelessWidget {
  const _MicroDashboard({
    required this.onReport,
    required this.onTips,
    required this.onHistory,
  });

  final VoidCallback onReport;
  final VoidCallback onTips;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;
    final l10n = context.l10n;

    return Container(
      width: 58,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        children: [
          _RoundAction(
            icon: Icons.health_and_safety_outlined,
            tooltip: l10n.safetyTips,
            onTap: onTips,
          ),
          const SizedBox(height: 8),
          _RoundAction(
            icon: Icons.history_outlined,
            tooltip: l10n.incidentHistory,
            onTap: onHistory,
          ),
          const SizedBox(height: 8),
          _RoundAction(
            icon: Icons.add_location_alt_outlined,
            tooltip: l10n.reportIncident,
            onTap: onReport,
          ),
        ],
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;

    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(icon, color: colors.primaryText),
      style: IconButton.styleFrom(
        backgroundColor: colors.surface,
        minimumSize: const Size(48, 48),
        side: BorderSide(color: colors.outline),
      ),
    );
  }
}

class _IncidentPin extends StatelessWidget {
  const _IncidentPin({required this.level, required this.count});

  final String level;
  final int count;

  @override
  Widget build(BuildContext context) {
    final color = _hotspotColor(context, level);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.38), blurRadius: 18),
            ],
          ),
          child: Center(
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

Color _hotspotColor(BuildContext context, String level) {
  final colors = context.safetyColors;
  return switch (level.toUpperCase()) {
    'CRITICAL' || 'HIGH' => colors.accent,
    'MEDIUM' || 'MODERATE' => colors.warning,
    _ => colors.safe,
  };
}

class _MapBottomSheet extends StatelessWidget {
  const _MapBottomSheet({
    required this.center,
    required this.hotspots,
    required this.loading,
    required this.onRefresh,
    this.error,
  });

  final LatLng center;
  final List<dynamic> hotspots;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: colors.handle,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _HotspotSummary(
            count: hotspots.length,
            loading: loading,
            error: error,
            onRefresh: onRefresh,
          ),
          const SizedBox(height: 8),
          Text(
            '${center.latitude.toStringAsFixed(5)}, ${center.longitude.toStringAsFixed(5)}',
            style: TextStyle(
              color: colors.secondaryText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _HotspotSummary extends StatelessWidget {
  const _HotspotSummary({
    required this.count,
    required this.loading,
    required this.onRefresh,
    this.error,
  });

  final int count;
  final bool loading;
  final String? error;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;
    final l10n = context.l10n;
    final hasError = error != null;
    final icon = hasError
        ? Icons.cloud_off_outlined
        : loading
            ? Icons.sync
            : Icons.shield_outlined;
    final color = hasError
        ? colors.warning
        : loading
            ? colors.warning
            : colors.safe;
    final label = hasError
        ? l10n.backendNeedsAttention
        : loading
            ? l10n.loadingHotspotZones
            : l10n.activeHotspotZonesNearby(count);

    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: colors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (hasError)
          IconButton(
            tooltip: l10n.retryHotspotFetch,
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
      ],
    );
  }
}
