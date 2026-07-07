import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/tactical_theme.dart';

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, this.compact = false});

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(label);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        context.l10n.code(label),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 11 : 12,
        ),
      ),
    );
  }

  Color _colorFor(String value) {
    switch (value) {
      case 'CRITICAL':
      case 'REPORTED':
      case 'IOT_BUTTON':
        return TacticalColors.critical;
      case 'HIGH':
      case 'DISPATCHED':
        return TacticalColors.pending;
      case 'MEDIUM':
      case 'ACKNOWLEDGED':
        return TacticalColors.low;
      case 'RESOLVED':
        return TacticalColors.active;
      default:
        return TacticalColors.textMuted;
    }
  }
}
