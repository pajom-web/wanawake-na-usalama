import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../models/hotspot.dart';
import '../models/incident.dart';
import '../models/patrol_asset.dart';
import '../models/safety_tip.dart';
import '../state/app_state.dart';
import '../theme/tactical_theme.dart';
import '../widgets/safety_map.dart';
import '../widgets/status_chip.dart';
import 'police_login_page.dart';

class PoliceDashboardPage extends ConsumerStatefulWidget {
  const PoliceDashboardPage({super.key});

  @override
  ConsumerState<PoliceDashboardPage> createState() =>
      _PoliceDashboardPageState();
}

enum _MapFocusLayer { dangerAlerts, patrolAssets, highRisk, lowRisk }

class _PoliceDashboardPageState extends ConsumerState<PoliceDashboardPage> {
  LatLng? _pickedHotspotCenter;
  LatLng? _mapFocusCenter;
  _MapFocusLayer? _lastFocusLayer;
  int? _lastFocusIndex;
  int _mapFocusRevision = 0;
  String _incidentFilter = 'ALL';
  bool _showHotspotForm = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(policeControllerProvider);
    final controller = ref.read(policeControllerProvider.notifier);
    final l10n = context.l10n;

    if (state.isLoading && !state.isAuthenticated) {
      return Center(child: CircularProgressIndicator());
    }
    if (!state.isAuthenticated) {
      return PoliceLoginPage();
    }

    final center =
        _mapFocusCenter ?? _pickedHotspotCenter ?? _bestMapCenter(state);
    final incidents = _filteredIncidents(state.incidents);
    final statusBar = _DispatchStatusBar(
      pendingCount: state.incidents
          .where((item) => item.status != 'RESOLVED')
          .length,
      hotspotCount: state.hotspots.where((item) => item.active).length,
      socketConnected: state.socketConnected,
      officerName:
          state.user?['full_name']?.toString() ??
          state.user?['username']?.toString() ??
          l10n.t('dispatch.officer'),
      badgeNumber:
          state.user?['badge_number']?.toString() ?? l10n.t('dispatch.noBadge'),
      rank:
          state.user?['rank_display']?.toString() ??
          state.user?['rank']?.toString() ??
          l10n.t('dispatch.officer'),
      station:
          state.user?['station']?.toString() ??
          l10n.t('dispatch.unassignedStation'),
      onRefresh: controller.refresh,
      onLogout: controller.logout,
    );
    final feed = _IncidentFeed(
      allIncidents: state.incidents,
      incidents: incidents,
      selectedFilter: _incidentFilter,
      onFilter: (value) => setState(() => _incidentFilter = value),
      onStatus: controller.updateIncidentStatus,
    );
    final map = _OperationsMap(
      center: center,
      focusRevision: _mapFocusRevision,
      incidents: state.incidents,
      hotspots: state.hotspots,
      patrolAssets: state.patrolAssets,
      onTap: (point) {
        setState(() {
          _pickedHotspotCenter = point;
          _mapFocusCenter = null;
          _lastFocusLayer = null;
          _lastFocusIndex = null;
          _mapFocusRevision++;
        });
      },
      onFocusLayer: (layer) => _focusMapLayer(state, center, layer),
    );
    final intelligence = _ThreatIntelligencePanel(
      hotspots: state.hotspots,
      patrolAssets: state.patrolAssets,
      safetyTips: state.safetyTips,
      canManageSafetyTips: state.user?['can_manage_safety_tips'] == true,
      pickedCenter: _pickedHotspotCenter,
      showForm: _showHotspotForm,
      onToggleForm: () => setState(() => _showHotspotForm = !_showHotspotForm),
      onCreateHotspot: controller.createHotspot,
      onSetHotspotRisk: controller.setHotspotRisk,
      onDeactivateHotspot: controller.deactivateHotspot,
      onCreatePatrolAsset: controller.createPatrolAsset,
      onMovePatrolAsset: controller.movePatrolAsset,
      onDeactivatePatrolAsset: controller.deactivatePatrolAsset,
      onSaveSafetyTip: controller.saveSafetyTip,
      onDeactivateSafetyTip: controller.deactivateSafetyTip,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1180;
        if (wide) {
          return Column(
            children: [
              statusBar,
              if (state.error != null)
                _ErrorStrip(message: l10n.error(state.error!)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 25, child: feed),
                      SizedBox(width: 12),
                      Expanded(flex: 50, child: map),
                      SizedBox(width: 12),
                      Expanded(flex: 25, child: intelligence),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: EdgeInsets.only(bottom: 16),
          children: [
            statusBar,
            if (state.error != null)
              _ErrorStrip(message: l10n.error(state.error!)),
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  SizedBox(height: 560, child: map),
                  SizedBox(height: 12),
                  SizedBox(height: 640, child: feed),
                  SizedBox(height: 12),
                  SizedBox(height: 760, child: intelligence),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  List<Incident> _filteredIncidents(List<Incident> incidents) {
    switch (_incidentFilter) {
      case 'SEVERE':
        return incidents
            .where(
              (item) => item.severity == 'CRITICAL' || item.severity == 'HIGH',
            )
            .toList();
      case 'PENDING':
        return incidents.where((item) => item.status != 'RESOLVED').toList();
      case 'CLOSED':
        return incidents.where((item) => item.status == 'RESOLVED').toList();
      default:
        return incidents;
    }
  }

  LatLng _bestMapCenter(PoliceState state) {
    for (final incident in state.incidents) {
      if (incident.status != 'RESOLVED' && incident.status != 'FALSE_ALARM') {
        return LatLng(incident.latitude, incident.longitude);
      }
    }
    if (state.patrolAssets.isNotEmpty) {
      final asset = state.patrolAssets.first;
      return LatLng(asset.latitude, asset.longitude);
    }
    if (state.hotspots.isNotEmpty) {
      final hotspot = state.hotspots.first;
      return LatLng(hotspot.centerLatitude, hotspot.centerLongitude);
    }
    return defaultMapCenter;
  }

  void _focusMapLayer(
    PoliceState state,
    LatLng currentCenter,
    _MapFocusLayer layer,
  ) {
    final targets = _mapFocusTargets(state, layer);
    if (targets.isEmpty) {
      return;
    }

    var targetIndex = _nearestTargetIndex(currentCenter, targets);
    if (_lastFocusLayer == layer && _lastFocusIndex != null) {
      targetIndex = (_lastFocusIndex! + 1) % targets.length;
    }

    setState(() {
      _mapFocusCenter = targets[targetIndex];
      _lastFocusLayer = layer;
      _lastFocusIndex = targetIndex;
      _mapFocusRevision++;
    });
  }

  List<LatLng> _mapFocusTargets(PoliceState state, _MapFocusLayer layer) {
    return switch (layer) {
      _MapFocusLayer.dangerAlerts =>
        state.incidents
            .where(_isActiveDangerAlert)
            .map((incident) => LatLng(incident.latitude, incident.longitude))
            .toList(),
      _MapFocusLayer.patrolAssets =>
        state.patrolAssets
            .where((asset) => asset.active)
            .map((asset) => LatLng(asset.latitude, asset.longitude))
            .toList(),
      _MapFocusLayer.highRisk =>
        state.hotspots
            .where((hotspot) => hotspot.active && hotspot.riskLevel == 'HIGH')
            .map(
              (hotspot) =>
                  LatLng(hotspot.centerLatitude, hotspot.centerLongitude),
            )
            .toList(),
      _MapFocusLayer.lowRisk =>
        state.hotspots
            .where((hotspot) => hotspot.active && hotspot.riskLevel == 'LOW')
            .map(
              (hotspot) =>
                  LatLng(hotspot.centerLatitude, hotspot.centerLongitude),
            )
            .toList(),
    };
  }

  int _nearestTargetIndex(LatLng center, List<LatLng> targets) {
    var nearestIndex = 0;
    var nearestDistance = double.infinity;
    for (var index = 0; index < targets.length; index++) {
      final target = targets[index];
      final latitudeDelta = target.latitude - center.latitude;
      final longitudeDelta = target.longitude - center.longitude;
      final distance =
          latitudeDelta * latitudeDelta + longitudeDelta * longitudeDelta;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = index;
      }
    }
    return nearestIndex;
  }
}

class _DispatchStatusBar extends StatelessWidget {
  const _DispatchStatusBar({
    required this.pendingCount,
    required this.hotspotCount,
    required this.socketConnected,
    required this.officerName,
    required this.badgeNumber,
    required this.rank,
    required this.station,
    required this.onRefresh,
    required this.onLogout,
  });

  final int pendingCount;
  final int hotspotCount;
  final bool socketConnected;
  final String officerName;
  final String badgeNumber;
  final String rank;
  final String station;
  final VoidCallback onRefresh;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TacticalColors.surface,
        border: Border(bottom: BorderSide(color: TacticalColors.border)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          /*_UtilitySegment(
            icon: Icons.sensors,
            label: l10n.t('dispatch.liveFeed'),
            active: true,
          ),*/
          _PulseAlert(count: pendingCount),
          _TelemetryBadge(
            icon: Icons.location_on_outlined,
            label: l10n.t('dispatch.hotspots', {'count': hotspotCount}),
            color: TacticalColors.pending,
          ),
          _TelemetryBadge(
            icon: socketConnected ? Icons.wifi_tethering : Icons.wifi_off,
            label: socketConnected
                ? l10n.t('dispatch.stable')
                : l10n.t('dispatch.offline'),
            color: socketConnected
                ? TacticalColors.active
                : TacticalColors.critical,
          ),
          _TelemetryBadge(
            icon: Icons.badge_outlined,
            label: '$officerName · $badgeNumber'.toUpperCase(),
            color: TacticalColors.low,
          ),
          _TelemetryBadge(
            icon: Icons.military_tech_outlined,
            label: rank.toUpperCase(),
            color: TacticalColors.active,
          ),
          _TelemetryBadge(
            icon: Icons.account_balance_outlined,
            label: station.toUpperCase(),
            color: TacticalColors.textMuted,
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: l10n.t('dispatch.refresh'),
            icon: Icon(Icons.refresh),
          ),
          IconButton(
            onPressed: onLogout,
            tooltip: l10n.t('dispatch.logout'),
            icon: Icon(Icons.logout),
          ),
        ],
      ),
    );
  }
}

class _PulseAlert extends StatefulWidget {
  const _PulseAlert({required this.count});

  final int count;

  @override
  State<_PulseAlert> createState() => _PulseAlertState();
}

class _PulseAlertState extends State<_PulseAlert>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1300),
      lowerBound: 0.25,
      upperBound: 0.75,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: TacticalColors.critical.withValues(alpha: 0.12),
            border: Border.all(
              color: TacticalColors.critical.withValues(alpha: 0.75),
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: TacticalColors.critical.withValues(
                  alpha: _controller.value * 0.35,
                ),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.emergency_share_outlined,
            size: 16,
            color: TacticalColors.critical,
          ),
          SizedBox(width: 7),
          Text(
            l10n.t('dispatch.pendingSos', {'count': widget.count}),
            style: tacticalMono(
              color: TacticalColors.critical,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

/*class _UtilitySegment extends StatelessWidget {
  const _UtilitySegment({
    required this.icon,
    required this.label,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? TacticalColors.active : TacticalColors.textMuted;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: active ? TacticalColors.active.withValues(alpha: 0.08) : null,
        border: Border.all(
          color: active ? TacticalColors.active : TacticalColors.border,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}*/

class _TelemetryBadge extends    StatelessWidget {
  const _TelemetryBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: TacticalColors.background,
        border: Border.all(color: TacticalColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          SizedBox(width: 6),
          Text(label, style: tacticalMono(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

class _IncidentFeed extends StatelessWidget {
  const _IncidentFeed({
    required this.allIncidents,
    required this.incidents,
    required this.selectedFilter,
    required this.onFilter,
    required this.onStatus,
  });

  final List<Incident> allIncidents;
  final List<Incident> incidents;
  final String selectedFilter;
  final ValueChanged<String> onFilter;
  final Future<void> Function(String id, String status) onStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final severe = allIncidents
        .where((item) => item.severity == 'CRITICAL' || item.severity == 'HIGH')
        .length;
    final pending = allIncidents
        .where((item) => item.status != 'RESOLVED')
        .length;
    final closed = allIncidents
        .where((item) => item.status == 'RESOLVED')
        .length;

    return TacticalPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TacticalEyebrow(l10n.t('dispatch.incidentFeed')),
                SizedBox(height: 5),
                Text(
                  l10n.t('dispatch.priorityQueue'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _FilterPill(
                      label: l10n.t('dispatch.all'),
                      count: allIncidents.length,
                      selected: selectedFilter == 'ALL',
                      onTap: () => onFilter('ALL'),
                    ),
                    _FilterPill(
                      label: l10n.t('dispatch.severe'),
                      count: severe,
                      selected: selectedFilter == 'SEVERE',
                      color: TacticalColors.critical,
                      onTap: () => onFilter('SEVERE'),
                    ),
                    _FilterPill(
                      label: l10n.t('dispatch.pending'),
                      count: pending,
                      selected: selectedFilter == 'PENDING',
                      color: TacticalColors.pending,
                      onTap: () => onFilter('PENDING'),
                    ),
                    _FilterPill(
                      label: l10n.t('dispatch.closed'),
                      count: closed,
                      selected: selectedFilter == 'CLOSED',
                      color: TacticalColors.active,
                      onTap: () => onFilter('CLOSED'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: incidents.isEmpty
                ? _EmptyState(
                    icon: Icons.task_alt,
                    message: l10n.t('dispatch.noIncidents'),
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(10),
                    itemCount: incidents.length,
                    separatorBuilder: (_, _) => SizedBox(height: 9),
                    itemBuilder: (context, index) => _IncidentCard(
                      incident: incidents[index],
                      onStatus: onStatus,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.color = TacticalColors.low,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : TacticalColors.background,
          border: Border.all(color: selected ? color : TacticalColors.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          '$label ($count)',
          style: TextStyle(
            color: selected ? color : TacticalColors.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident, required this.onStatus});

  final Incident incident;
  final Future<void> Function(String id, String status) onStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final nextStatus = switch (incident.status) {
      'REPORTED' => 'ACKNOWLEDGED',
      'ACKNOWLEDGED' => 'DISPATCHED',
      _ => 'RESOLVED',
    };
    final eventTime = incident.pressedAt ?? incident.createdAt;
    final deviceId = incident.deviceId.isEmpty
        ? l10n.t('dispatch.unknownDevice')
        : incident.deviceId;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TacticalColors.background,
        border: Border.all(color: TacticalColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _incidentCode(incident.id),
                  style: tacticalMono(
                    color: TacticalColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (incident.isIotButton) ...[
                SizedBox(width: 6),
                StatusChip(label: incident.source, compact: true),
              ],
              SizedBox(width: 6),
              StatusChip(label: incident.severity, compact: true),
            ],
          ),
          SizedBox(height: 10),
          Text(
            _incidentTitle(context, incident),
            style: TextStyle(
              color: TacticalColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 15,
                color: TacticalColors.textMuted,
              ),
              SizedBox(width: 5),
              Expanded(
                child: Text(
                  '${incident.latitude.toStringAsFixed(5)}, '
                  '${incident.longitude.toStringAsFixed(5)}',
                  style: tacticalMono(
                    color: TacticalColors.textMuted,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 7),
          _IncidentMetaLine(
            icon: incident.isIotButton
                ? Icons.sensors
                : Icons.schedule_outlined,
            label: incident.isIotButton
                ? l10n.t('dispatch.source')
                : l10n.t('dispatch.reportedAt'),
            value: incident.isIotButton
                ? l10n.t('dispatch.iotPanicButton')
                : _formatTimestamp(eventTime),
          ),
          if (incident.isIotButton) ...[
            SizedBox(height: 6),
            _IncidentMetaLine(
              icon: Icons.memory_outlined,
              label: l10n.t('dispatch.device'),
              value: deviceId,
            ),
            SizedBox(height: 6),
            _IncidentMetaLine(
              icon: Icons.schedule_outlined,
              label: l10n.t('dispatch.pressedAt'),
              value: _formatTimestamp(eventTime),
            ),
          ],
          if (incident.description.isNotEmpty) ...[
            SizedBox(height: 7),
            Text(
              incident.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (incident.status == 'RESOLVED' &&
              incident.hasResolutionDetails) ...[
            SizedBox(height: 10),
            _ResolutionDetailsSection(incident: incident),
          ],
          SizedBox(height: 11),
          Row(
            children: [
              StatusChip(label: incident.status, compact: true),
              Spacer(),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onPressed: incident.status == 'RESOLVED'
                    ? null
                    : () => onStatus(incident.id, nextStatus),
                child: Text(l10n.t('dispatch.examine')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResolutionDetailsSection extends StatelessWidget {
  const _ResolutionDetailsSection({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final officerLabel = incident.solvedByBadgeNumber.isEmpty
        ? incident.solvedByName
        : '${incident.solvedByName} (${incident.solvedByBadgeNumber})';

    return Container(
      padding: EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: TacticalColors.active.withValues(alpha: 0.07),
        border: Border(
          left: BorderSide(color: TacticalColors.active, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.verified_user_outlined,
                size: 15,
                color: TacticalColors.active,
              ),
              SizedBox(width: 6),
              Text(
                l10n.t('dispatch.resolutionAudit'),
                style: tacticalMono(
                  color: TacticalColors.active,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          if (incident.solvedByName.isNotEmpty) ...[
            SizedBox(height: 7),
            _IncidentMetaLine(
              icon: Icons.local_police_outlined,
              label: l10n.t('dispatch.solvedBy'),
              value: officerLabel,
            ),
          ],
          if (incident.solvedByStation.isNotEmpty) ...[
            SizedBox(height: 6),
            _IncidentMetaLine(
              icon: Icons.account_balance_outlined,
              label: l10n.t('dispatch.solvedByStation'),
              value: incident.solvedByStation,
            ),
          ],
          if (incident.solvedAt != null) ...[
            SizedBox(height: 6),
            _IncidentMetaLine(
              icon: Icons.event_available_outlined,
              label: l10n.t('dispatch.solvedAt'),
              value: _formatTimestamp(incident.solvedAt!),
            ),
          ],
        ],
      ),
    );
  }
}

class _IncidentMetaLine extends StatelessWidget {
  const _IncidentMetaLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: TacticalColors.textMuted),
        SizedBox(width: 5),
        Text(
          '$label: ',
          style: tacticalMono(color: TacticalColors.textMuted, fontSize: 10),
        ),
        Expanded(
          child: Text(
            value,
            style: tacticalMono(color: TacticalColors.textMuted, fontSize: 10),
          ),
        ),
      ],
    );
  }
}

class _OperationsMap extends StatelessWidget {
  const _OperationsMap({
    required this.center,
    required this.focusRevision,
    required this.incidents,
    required this.hotspots,
    required this.patrolAssets,
    required this.onTap,
    required this.onFocusLayer,
  });

  final LatLng center;
  final int focusRevision;
  final List<Incident> incidents;
  final List<Hotspot> hotspots;
  final List<PatrolAsset> patrolAssets;
  final ValueChanged<LatLng> onTap;
  final ValueChanged<_MapFocusLayer> onFocusLayer;

  @override
  Widget build(BuildContext context) {
    return TacticalPanel(
      padding: EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4, 3, 4, 10),
            child: Row(
              children: [
                Icon(
                  Icons.grid_view_outlined,
                  color: TacticalColors.active,
                  size: 18,
                ),
                Spacer(),
                Text(
                  '${center.latitude.toStringAsFixed(4)} / '
                  '${center.longitude.toStringAsFixed(4)}',
                  style: tacticalMono(
                    color: TacticalColors.active,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: TacticalColors.borderStrong),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SafetyMap(
                      center: center,
                      focusRevision: focusRevision,
                      incidents: incidents,
                      hotspots: hotspots,
                      patrolAssets: patrolAssets,
                      onTap: onTap,
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _LayerControls(
                    hasDangerAlerts: incidents.any(_isActiveDangerAlert),
                    hasPatrolAssets: patrolAssets.any((asset) => asset.active),
                    hasHighRiskAreas: hotspots.any(
                      (hotspot) =>
                          hotspot.active && hotspot.riskLevel == 'HIGH',
                    ),
                    hasLowRiskAreas: hotspots.any(
                      (hotspot) => hotspot.active && hotspot.riskLevel == 'LOW',
                    ),
                    onFocusLayer: onFocusLayer,
                  ),
                ),
                Positioned(right: 12, top: 90, child: _MapNavigation()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LayerControls extends StatelessWidget {
  const _LayerControls({
    required this.hasDangerAlerts,
    required this.hasPatrolAssets,
    required this.hasHighRiskAreas,
    required this.hasLowRiskAreas,
    required this.onFocusLayer,
  });

  final bool hasDangerAlerts;
  final bool hasPatrolAssets;
  final bool hasHighRiskAreas;
  final bool hasLowRiskAreas;
  final ValueChanged<_MapFocusLayer> onFocusLayer;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: TacticalColors.background.withValues(alpha: 0.92),
        border: Border.all(color: TacticalColors.borderStrong),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          _MapControlPill(
            icon: Icons.sensors,
            label: l10n.t('dispatch.dangerAlerts'),
            color: TacticalColors.critical,
            onPressed: hasDangerAlerts
                ? () => onFocusLayer(_MapFocusLayer.dangerAlerts)
                : null,
          ),
          _MapControlPill(
            icon: Icons.visibility_outlined,
            label: l10n.t('dispatch.patrolAssets'),
            color: TacticalColors.active,
            onPressed: hasPatrolAssets
                ? () => onFocusLayer(_MapFocusLayer.patrolAssets)
                : null,
          ),
          _MapControlPill(
            icon: Icons.local_fire_department_outlined,
            label: l10n.t('dispatch.riskHigh'),
            color: TacticalColors.critical,
            onPressed: hasHighRiskAreas
                ? () => onFocusLayer(_MapFocusLayer.highRisk)
                : null,
          ),
          _MapControlPill(
            icon: Icons.warning_amber_outlined,
            label: l10n.t('dispatch.riskLow'),
            color: TacticalColors.pending,
            onPressed: hasLowRiskAreas
                ? () => onFocusLayer(_MapFocusLayer.lowRisk)
                : null,
          ),
        ],
      ),
    );
  }
}

class _MapControlPill extends StatelessWidget {
  const _MapControlPill({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(7),
            child: AnimatedOpacity(
              duration: Duration(milliseconds: 150),
              opacity: enabled ? 1 : 0.38,
              child: Container(
                width: 34,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  border: Border.all(color: color.withValues(alpha: 0.55)),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapNavigation extends StatelessWidget {
  const _MapNavigation();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      decoration: BoxDecoration(
        color: TacticalColors.background.withValues(alpha: 0.92),
        border: Border.all(color: TacticalColors.borderStrong),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MapNavIcon(icon: Icons.add, tooltip: l10n.t('dispatch.zoomIn')),
          Divider(height: 1),
          _MapNavIcon(icon: Icons.remove, tooltip: l10n.t('dispatch.zoomOut')),
          Divider(height: 1),
          _MapNavIcon(
            icon: Icons.my_location,
            tooltip: l10n.t('dispatch.centerGrid'),
          ),
        ],
      ),
    );
  }
}

class _MapNavIcon extends StatelessWidget {
  const _MapNavIcon({required this.icon, required this.tooltip});

  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Padding(
        padding: EdgeInsets.all(9),
        child: Icon(icon, size: 16, color: TacticalColors.text),
      ),
    );
  }
}

class _ThreatIntelligencePanel extends StatelessWidget {
  const _ThreatIntelligencePanel({
    required this.hotspots,
    required this.patrolAssets,
    required this.safetyTips,
    required this.canManageSafetyTips,
    required this.pickedCenter,
    required this.showForm,
    required this.onToggleForm,
    required this.onCreateHotspot,
    required this.onSetHotspotRisk,
    required this.onDeactivateHotspot,
    required this.onCreatePatrolAsset,
    required this.onMovePatrolAsset,
    required this.onDeactivatePatrolAsset,
    required this.onSaveSafetyTip,
    required this.onDeactivateSafetyTip,
  });

  final List<Hotspot> hotspots;
  final List<PatrolAsset> patrolAssets;
  final List<SafetyTip> safetyTips;
  final bool canManageSafetyTips;
  final LatLng? pickedCenter;
  final bool showForm;
  final VoidCallback onToggleForm;
  final Future<void> Function(Hotspot hotspot) onCreateHotspot;
  final Future<void> Function(Hotspot hotspot, String riskLevel)
  onSetHotspotRisk;
  final Future<void> Function(Hotspot hotspot) onDeactivateHotspot;
  final Future<void> Function(PatrolAsset asset) onCreatePatrolAsset;
  final Future<void> Function(PatrolAsset asset, LatLng location)
  onMovePatrolAsset;
  final Future<void> Function(PatrolAsset asset) onDeactivatePatrolAsset;
  final Future<void> Function(SafetyTip tip) onSaveSafetyTip;
  final Future<void> Function(SafetyTip tip) onDeactivateSafetyTip;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TacticalPanel(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TacticalEyebrow(l10n.t('dispatch.threatIntelligence')),
                SizedBox(height: 5),
                Text(
                  l10n.t('dispatch.mapLayerManagement'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 14),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: showForm
                        ? TacticalColors.pending
                        : TacticalColors.active,
                  ),
                  onPressed: onToggleForm,
                  icon: Icon(showForm ? Icons.close : Icons.gesture),
                  label: Text(
                    showForm
                        ? l10n.t('dispatch.closeDrawing')
                        : l10n.t('dispatch.drawHotspot'),
                  ),
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TacticalColors.background,
                    border: Border.all(color: TacticalColors.border),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TacticalEyebrow(l10n.t('dispatch.hotspotHelp')),
                      SizedBox(height: 7),
                      Text(l10n.t('dispatch.hotspotInstructions')),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(14),
              child: showForm
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _HotspotForm(
                          pickedCenter: pickedCenter,
                          onCreate: onCreateHotspot,
                        ),
                        SizedBox(height: 20),
                        Divider(),
                        SizedBox(height: 12),
                        _PatrolAssetForm(
                          pickedCenter: pickedCenter,
                          onCreate: onCreatePatrolAsset,
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (canManageSafetyTips) ...[
                          _SafetyTipManager(
                            tips: safetyTips,
                            onSave: onSaveSafetyTip,
                            onDeactivate: onDeactivateSafetyTip,
                          ),
                          SizedBox(height: 20),
                          Divider(),
                          SizedBox(height: 12),
                        ],
                        _HotspotList(
                          hotspots: hotspots,
                          onSetRisk: onSetHotspotRisk,
                          onDeactivate: onDeactivateHotspot,
                        ),
                        SizedBox(height: 20),
                        Divider(),
                        SizedBox(height: 12),
                        _PatrolAssetList(
                          assets: patrolAssets,
                          pickedCenter: pickedCenter,
                          onMove: onMovePatrolAsset,
                          onDeactivate: onDeactivatePatrolAsset,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafetyTipManager extends StatefulWidget {
  const _SafetyTipManager({
    required this.tips,
    required this.onSave,
    required this.onDeactivate,
  });

  final List<SafetyTip> tips;
  final Future<void> Function(SafetyTip tip) onSave;
  final Future<void> Function(SafetyTip tip) onDeactivate;

  @override
  State<_SafetyTipManager> createState() => _SafetyTipManagerState();
}

class _SafetyTipManagerState extends State<_SafetyTipManager> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _categoryController = TextEditingController();
  final _orderController = TextEditingController(text: '0');
  SafetyTip? _editing;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _categoryController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.only(top: 10),
        leading: Icon(
          Icons.tips_and_updates_outlined,
          color: TacticalColors.active,
        ),
        title: TacticalEyebrow(l10n.t('dispatch.safetyTips')),
        subtitle: Text(l10n.t('dispatch.safetyTipsHelp')),
        children: [
          TextField(
            controller: _titleController,
            decoration: InputDecoration(labelText: l10n.t('dispatch.tipTitle')),
          ),
          SizedBox(height: 9),
          TextField(
            controller: _bodyController,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(labelText: l10n.t('dispatch.tipBody')),
          ),
          SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _categoryController,
                  decoration: InputDecoration(
                    labelText: l10n.t('dispatch.tipCategory'),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _orderController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: l10n.t('dispatch.tipOrder'),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: TacticalColors.critical)),
          ],
          SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _editing == null ? Icons.add : Icons.save_outlined,
                        ),
                  label: Text(
                    l10n.t(
                      _editing == null
                          ? 'dispatch.publishTip'
                          : 'dispatch.updateTip',
                    ),
                  ),
                ),
              ),
              if (_editing != null) ...[
                SizedBox(width: 8),
                IconButton(
                  tooltip: l10n.t('dispatch.cancelEdit'),
                  onPressed: _clearForm,
                  icon: Icon(Icons.close),
                ),
              ],
            ],
          ),
          SizedBox(height: 14),
          if (widget.tips.isEmpty)
            _EmptyState(
              icon: Icons.tips_and_updates_outlined,
              message: l10n.t('dispatch.noSafetyTips'),
            )
          else
            ...widget.tips.map(
              (tip) => Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: TacticalColors.background,
                  border: Border.all(color: TacticalColors.border),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tip.title,
                            style: TextStyle(
                              color: TacticalColors.text,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Text(
                          '#${tip.displayOrder}',
                          style: tacticalMono(
                            color: TacticalColors.active,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    if (tip.category.isNotEmpty) ...[
                      SizedBox(height: 3),
                      TacticalEyebrow(tip.category),
                    ],
                    SizedBox(height: 6),
                    Text(tip.body),
                    SizedBox(height: 7),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () => _edit(tip),
                          icon: Icon(Icons.edit_outlined, size: 16),
                          label: Text(l10n.t('dispatch.edit')),
                        ),
                        IconButton(
                          tooltip: l10n.t('dispatch.deactivate'),
                          visualDensity: VisualDensity.compact,
                          onPressed: () => widget.onDeactivate(tip),
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: TacticalColors.textMuted,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _edit(SafetyTip tip) {
    setState(() {
      _editing = tip;
      _titleController.text = tip.title;
      _bodyController.text = tip.body;
      _categoryController.text = tip.category;
      _orderController.text = tip.displayOrder.toString();
      _error = null;
    });
  }

  void _clearForm() {
    setState(() {
      _editing = null;
      _titleController.clear();
      _bodyController.clear();
      _categoryController.clear();
      _orderController.text = '0';
      _error = null;
    });
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    final order = int.tryParse(_orderController.text.trim());
    if (title.isEmpty || body.isEmpty || order == null || order < 0) {
      setState(() => _error = context.l10n.t('dispatch.invalidSafetyTip'));
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final editing = _editing;
    await widget.onSave(
      SafetyTip(
        id: editing?.id ?? 0,
        title: title,
        body: body,
        category: _categoryController.text.trim(),
        isActive: true,
        displayOrder: order,
        publishedAt: editing?.publishedAt ?? now,
        createdAt: editing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    if (mounted) {
      _clearForm();
      setState(() => _saving = false);
    }
  }
}

class _HotspotList extends StatelessWidget {
  const _HotspotList({
    required this.hotspots,
    required this.onSetRisk,
    required this.onDeactivate,
  });

  final List<Hotspot> hotspots;
  final Future<void> Function(Hotspot hotspot, String riskLevel) onSetRisk;
  final Future<void> Function(Hotspot hotspot) onDeactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (hotspots.isEmpty) {
      return _EmptyState(
        icon: Icons.radar,
        message: l10n.t('dispatch.noHotspots'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TacticalEyebrow(l10n.t('dispatch.registeredHotspots')),
            ),
            Text(
              l10n.t('dispatch.active', {'count': hotspots.length}),
              style: tacticalMono(color: TacticalColors.active, fontSize: 10),
            ),
          ],
        ),
        SizedBox(height: 10),
        ...hotspots.map(
          (hotspot) => Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: TacticalColors.background,
              border: Border.all(color: TacticalColors.border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: _riskColor(hotspot.riskLevel),
                  size: 18,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hotspot.title,
                        style: TextStyle(
                          color: TacticalColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        l10n.t('dispatch.radiusRisk', {
                          'radius': hotspot.radiusMeters,
                          'risk': l10n.code(hotspot.riskLevel),
                        }),
                        style: tacticalMono(
                          color: TacticalColors.textMuted,
                          fontSize: 9,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        hotspot.isAutomatic
                            ? l10n.t('dispatch.automaticZone', {
                                'count': hotspot.incidentCount,
                              })
                            : l10n.t('dispatch.manualZone'),
                        style: tacticalMono(
                          color: hotspot.isAutomatic
                              ? TacticalColors.pending
                              : TacticalColors.active,
                          fontSize: 9,
                        ),
                      ),
                      SizedBox(height: 6),
                      Wrap(
                        spacing: 2,
                        children: [
                          Tooltip(
                            message: l10n.t('dispatch.setLowRisk'),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: hotspot.riskLevel == 'LOW'
                                  ? null
                                  : () => onSetRisk(hotspot, 'LOW'),
                              icon: Icon(
                                Icons.shield_outlined,
                                color: TacticalColors.low,
                                size: 18,
                              ),
                            ),
                          ),
                          Tooltip(
                            message: l10n.t('dispatch.setHighRisk'),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: hotspot.riskLevel == 'HIGH'
                                  ? null
                                  : () => onSetRisk(hotspot, 'HIGH'),
                              icon: Icon(
                                Icons.warning_amber_rounded,
                                color: TacticalColors.critical,
                                size: 18,
                              ),
                            ),
                          ),
                          Tooltip(
                            message: l10n.t('dispatch.deactivate'),
                            child: IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: () => onDeactivate(hotspot),
                              icon: Icon(
                                Icons.remove_circle_outline,
                                color: TacticalColors.textMuted,
                                size: 18,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HotspotForm extends StatefulWidget {
  const _HotspotForm({required this.pickedCenter, required this.onCreate});

  final LatLng? pickedCenter;
  final Future<void> Function(Hotspot hotspot) onCreate;

  @override
  State<_HotspotForm> createState() => _HotspotFormState();
}

class _HotspotFormState extends State<_HotspotForm> {
  final _titleController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _radiusController = TextEditingController(text: '300');
  final _notesController = TextEditingController();
  String _riskLevel = 'HIGH';
  String? _error;
  bool _saving = false;
  String? _localizedDefaultTitle;

  @override
  void initState() {
    super.initState();
    _syncCoordinates();
  }

  @override
  void didUpdateWidget(covariant _HotspotForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pickedCenter != oldWidget.pickedCenter) {
      _syncCoordinates();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final translatedDefault = context.l10n.t('dispatch.unsafeZone');
    if (_titleController.text.isEmpty ||
        _titleController.text == _localizedDefaultTitle) {
      _titleController.text = translatedDefault;
    }
    _localizedDefaultTitle = translatedDefault;
  }

  void _syncCoordinates() {
    if (widget.pickedCenter == null) {
      return;
    }
    _latController.text = widget.pickedCenter!.latitude.toStringAsFixed(6);
    _lonController.text = widget.pickedCenter!.longitude.toStringAsFixed(6);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _radiusController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TacticalEyebrow(
          l10n.t('dispatch.drawingActive'),
          color: TacticalColors.pending,
        ),
        SizedBox(height: 6),
        Text(l10n.t('dispatch.tapCoordinates')),
        SizedBox(height: 14),
        TextField(
          controller: _titleController,
          decoration: InputDecoration(labelText: l10n.t('dispatch.zoneTitle')),
        ),
        SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _latController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.t('dispatch.latitude'),
                ),
              ),
            ),
            SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _lonController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: l10n.t('dispatch.longitude'),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 10),
        TextField(
          controller: _radiusController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.t('dispatch.radius')),
        ),
        SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _riskLevel,
          decoration: InputDecoration(labelText: l10n.t('dispatch.riskLevel')),
          items: [
            DropdownMenuItem(value: 'LOW', child: Text(l10n.code('LOW'))),
            DropdownMenuItem(value: 'HIGH', child: Text(l10n.code('HIGH'))),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _riskLevel = value);
            }
          },
        ),
        SizedBox(height: 10),
        TextField(
          controller: _notesController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.t('dispatch.operatorNotes'),
          ),
        ),
        if (_error != null) ...[
          SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: TacticalColors.critical)),
        ],
        SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _create,
          icon: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.add_location_alt_outlined),
          label: Text(l10n.t('dispatch.registerHotspot')),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final latitude = double.tryParse(_latController.text.trim());
    final longitude = double.tryParse(_lonController.text.trim());
    final radius = int.tryParse(_radiusController.text.trim());
    if (latitude == null || longitude == null || radius == null) {
      setState(() => _error = context.l10n.t('dispatch.invalidCoordinates'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.onCreate(
      Hotspot(
        id: 0,
        title: _titleController.text.trim().isEmpty
            ? context.l10n.t('dispatch.unsafeZone')
            : _titleController.text.trim(),
        centerLatitude: latitude,
        centerLongitude: longitude,
        radiusMeters: radius,
        riskLevel: _riskLevel,
        active: true,
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    if (mounted) {
      setState(() => _saving = false);
    }
  }
}

class _PatrolAssetList extends StatelessWidget {
  const _PatrolAssetList({
    required this.assets,
    required this.pickedCenter,
    required this.onMove,
    required this.onDeactivate,
  });

  final List<PatrolAsset> assets;
  final LatLng? pickedCenter;
  final Future<void> Function(PatrolAsset asset, LatLng location) onMove;
  final Future<void> Function(PatrolAsset asset) onDeactivate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (assets.isEmpty) {
      return _EmptyState(
        icon: Icons.local_police_outlined,
        message: l10n.t('dispatch.noPatrolAssets'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TacticalEyebrow(l10n.t('dispatch.registeredPatrolAssets')),
            ),
            Text(
              l10n.t('dispatch.active', {'count': assets.length}),
              style: tacticalMono(color: TacticalColors.active, fontSize: 10),
            ),
          ],
        ),
        SizedBox(height: 10),
        ...assets.map(
          (asset) => Container(
            margin: EdgeInsets.only(bottom: 8),
            padding: EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: TacticalColors.background,
              border: Border.all(color: TacticalColors.border),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.local_police_outlined,
                  color: TacticalColors.active,
                  size: 18,
                ),
                SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        style: TextStyle(
                          color: TacticalColors.text,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${context.l10n.code(asset.status)} | '
                        '${asset.latitude.toStringAsFixed(4)} / '
                        '${asset.longitude.toStringAsFixed(4)}',
                        style: tacticalMono(
                          color: TacticalColors.textMuted,
                          fontSize: 9,
                        ),
                      ),
                      SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            onPressed: pickedCenter == null
                                ? null
                                : () => onMove(asset, pickedCenter!),
                            icon: Icon(Icons.pin_drop_outlined, size: 16),
                            label: Text(l10n.t('dispatch.moveHere')),
                          ),
                          IconButton(
                            tooltip: l10n.t('dispatch.deactivate'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => onDeactivate(asset),
                            icon: Icon(
                              Icons.remove_circle_outline,
                              color: TacticalColors.textMuted,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PatrolAssetForm extends StatefulWidget {
  const _PatrolAssetForm({required this.pickedCenter, required this.onCreate});

  final LatLng? pickedCenter;
  final Future<void> Function(PatrolAsset asset) onCreate;

  @override
  State<_PatrolAssetForm> createState() => _PatrolAssetFormState();
}

class _PatrolAssetFormState extends State<_PatrolAssetForm> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  String _status = 'AVAILABLE';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TacticalEyebrow(
          l10n.t('dispatch.patrolAssetManagement'),
          color: TacticalColors.active,
        ),
        SizedBox(height: 6),
        Text(l10n.t('dispatch.patrolAssetInstructions')),
        SizedBox(height: 14),
        TextField(
          controller: _nameController,
          decoration: InputDecoration(labelText: l10n.t('dispatch.assetName')),
        ),
        SizedBox(height: 10),
        DropdownButtonFormField<String>(
          initialValue: _status,
          decoration: InputDecoration(
            labelText: l10n.t('dispatch.assetStatus'),
          ),
          items: [
            DropdownMenuItem(
              value: 'AVAILABLE',
              child: Text(l10n.code('AVAILABLE')),
            ),
            DropdownMenuItem(
              value: 'DEPLOYED',
              child: Text(l10n.code('DEPLOYED')),
            ),
            DropdownMenuItem(
              value: 'OFFLINE',
              child: Text(l10n.code('OFFLINE')),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _status = value);
            }
          },
        ),
        SizedBox(height: 10),
        TextField(
          controller: _notesController,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: l10n.t('dispatch.operatorNotes'),
          ),
        ),
        if (_error != null) ...[
          SizedBox(height: 10),
          Text(_error!, style: TextStyle(color: TacticalColors.critical)),
        ],
        SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _saving ? null : _create,
          icon: _saving
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.add_location_alt_outlined),
          label: Text(l10n.t('dispatch.registerPatrolAsset')),
        ),
      ],
    );
  }

  Future<void> _create() async {
    final point = widget.pickedCenter;
    final name = _nameController.text.trim();
    if (point == null || name.isEmpty) {
      setState(() => _error = context.l10n.t('dispatch.invalidPatrolAsset'));
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    await widget.onCreate(
      PatrolAsset(
        id: 0,
        name: name,
        latitude: point.latitude,
        longitude: point.longitude,
        status: _status,
        active: true,
        notes: _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    if (mounted) {
      setState(() => _saving = false);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: TacticalColors.textMuted, size: 32),
            SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  const _ErrorStrip({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: TacticalColors.critical.withValues(alpha: 0.13),
      child: Text(
        message,
        style: TextStyle(
          color: TacticalColors.critical,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _incidentCode(String id) {
  final compact = id.replaceAll('-', '').toUpperCase();
  final suffix = compact.length > 7 ? compact.substring(0, 7) : compact;
  return 'INC-$suffix';
}

String _incidentTitle(BuildContext context, Incident incident) {
  if (incident.isIotButton) {
    return context.l10n.t('dispatch.iotButtonAlert');
  }
  if (incident.description.isNotEmpty) {
    return incident.description;
  }
  final l10n = context.l10n;
  return switch (incident.category) {
    'SOS' => l10n.t('incident.sos'),
    'HARASSMENT' => l10n.t('incident.harassment'),
    'STALKING' => l10n.t('incident.stalking'),
    'MEDICAL' => l10n.t('incident.medical'),
    _ => l10n.t('incident.brokenStreetlights'),
  };
}

String _formatTimestamp(DateTime timestamp) {
  final local = timestamp.toLocal();
  final offset = local.timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final offsetHours = offset.inHours.abs().toString().padLeft(2, '0');
  final offsetMinutes = (offset.inMinutes.abs() % 60).toString().padLeft(
    2,
    '0',
  );
  String two(int value) => value.toString().padLeft(2, '0');

  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)} '
      'UTC$sign$offsetHours:$offsetMinutes';
}

bool _isActiveDangerAlert(Incident incident) {
  return incident.status != 'RESOLVED' && incident.status != 'FALSE_ALARM';
}

Color _riskColor(String riskLevel) {
  return switch (riskLevel) {
    'HIGH' => TacticalColors.critical,
    _ => TacticalColors.low,
  };
}
