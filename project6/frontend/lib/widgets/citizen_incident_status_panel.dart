import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/incident.dart';
import '../theme/tactical_theme.dart';
import 'status_chip.dart';

class CitizenIncidentStatusPanel extends StatelessWidget {
  const CitizenIncidentStatusPanel({
    super.key,
    required this.incidents,
    required this.onRefresh,
  });

  final List<Incident> incidents;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: TacticalColors.active.withValues(alpha: 0.08),
        border: Border.all(color: TacticalColors.active.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.track_changes, color: TacticalColors.active),
              SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TacticalEyebrow(
                      l10n.t('router.reportStatus'),
                      color: TacticalColors.active,
                    ),
                    SizedBox(height: 3),
                    Text(l10n.t('router.reportStatusHelp')),
                  ],
                ),
              ),
              IconButton(
                onPressed: onRefresh,
                tooltip: l10n.t('router.refreshReportStatus'),
                icon: Icon(Icons.refresh),
              ),
            ],
          ),
          SizedBox(height: 10),
          ...incidents
              .take(5)
              .map(
                (incident) => Container(
                  margin: EdgeInsets.only(top: 7),
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: TacticalColors.background,
                    border: Border.all(color: TacticalColors.border),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _shortCode(incident.id),
                              style: tacticalMono(
                                color: TacticalColors.text,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _statusMessage(context, incident.status),
                              style: TextStyle(color: TacticalColors.textMuted),
                            ),
                            SizedBox(height: 4),
                            Text(
                              l10n.t('router.lastUpdated', {
                                'time': _formatIncidentUpdate(
                                  incident.updatedAt,
                                ),
                              }),
                              style: tacticalMono(
                                color: TacticalColors.textMuted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 8),
                      StatusChip(label: incident.status, compact: true),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

String _shortCode(String id) {
  final compact = id.replaceAll('-', '').toUpperCase();
  final suffix = compact.length > 7 ? compact.substring(0, 7) : compact;
  return 'INC-$suffix';
}

String _statusMessage(BuildContext context, String status) {
  return switch (status) {
    'ACKNOWLEDGED' => context.l10n.t('router.statusAcknowledged'),
    'DISPATCHED' => context.l10n.t('router.statusDispatched'),
    'RESOLVED' => context.l10n.t('router.statusResolved'),
    'FALSE_ALARM' => context.l10n.t('router.statusFalseAlarm'),
    _ => context.l10n.t('router.statusReported'),
  };
}

String _formatIncidentUpdate(DateTime value) {
  final local = value.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.day}/${local.month}/${local.year} $hour:$minute';
}
