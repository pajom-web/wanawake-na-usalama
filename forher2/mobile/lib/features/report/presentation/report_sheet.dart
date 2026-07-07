import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/safety_colors.dart';
import '../data/incident_repository.dart';
import '../domain/incident_type.dart';
import '../domain/report_submission_status.dart';
import 'incident_history_sheet.dart';
import 'report_status_controller.dart';

void showReportSheet(BuildContext context, LatLng point) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => ReportSheet(point: point),
  );
}

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({required this.point, super.key});

  final LatLng point;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  IncidentType _selected = IncidentType.harassment;
  final _notes = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;
    final l10n = context.l10n;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        10,
        20,
        MediaQuery.of(context).viewInsets.bottom + 22,
      ),
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
          const SizedBox(height: 18),
          Text(
            l10n.reportIncident,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final type in IncidentType.values)
                ChoiceChip(
                  label: Text(_incidentTypeLabel(l10n, type)),
                  selected: _selected == type,
                  onSelected: (_) => setState(() => _selected = type),
                  selectedColor: colors.accent,
                  backgroundColor: colors.canvas,
                  labelStyle: TextStyle(
                    color:
                        _selected == type ? Colors.white : colors.secondaryText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: l10n.optionalNotes,
              prefixIcon: const Icon(Icons.notes_outlined),
              fillColor: colors.canvas,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: colors.warning),
            ),
          ],
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.submitReport),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    setState(() {
      _submitting = true;
      _error = null;
    });
    ref.read(reportSubmissionStatusProvider.notifier).state =
        ReportSubmissionStatus.sending();
    try {
      final receipt = await ref.read(incidentRepositoryProvider).report(
            type: _selected,
            point: widget.point,
            title: _selected.label,
            description: _notes.text.trim(),
          );
      ref.read(reportSubmissionStatusProvider.notifier).state =
          ReportSubmissionStatus.received(reportId: receipt.id);
      ref.invalidate(incidentHistoryProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      ref.read(reportSubmissionStatusProvider.notifier).state =
          ReportSubmissionStatus.failed(error.toString());
      if (mounted) {
        setState(() => _error = l10n.reportSubmitFailed(error.toString()));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _incidentTypeLabel(AppLocalizations l10n, IncidentType type) {
    return switch (type) {
      IncidentType.harassment => l10n.harassment,
      IncidentType.poorLighting => l10n.poorLighting,
      IncidentType.unsafeStreet => l10n.unsafeStreet,
      IncidentType.desertedArea => l10n.desertedArea,
      IncidentType.suspiciousActivity => l10n.suspiciousActivity,
    };
  }
}
