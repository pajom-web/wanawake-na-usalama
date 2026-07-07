import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/tactical_theme.dart';
import '../widgets/citizen_incident_status_panel.dart';
import '../widgets/safety_map.dart';
import '../widgets/status_chip.dart';

class CitizenPage extends ConsumerStatefulWidget {
  const CitizenPage({super.key});

  @override
  ConsumerState<CitizenPage> createState() => _CitizenPageState();
}

class _CitizenPageState extends ConsumerState<CitizenPage> {
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _phoneController = TextEditingController();
  String _category = 'HARASSMENT';
  String _priority = 'LOW';

  @override
  void dispose() {
    _locationController.dispose();
    _descriptionController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(citizenControllerProvider);
    final controller = ref.read(citizenControllerProvider.notifier);
    final districtBar = _DistrictStatusBar(
      hotspotCount: state.hotspots.length,
      reportCount: state.incidents.length,
      onLocate: controller.useBrowserLocation,
      onRefresh: controller.refresh,
    );
    final mapPanel = _ContextMapPanel(state: state);
    final formPanel = _SecureRouterForm(
      state: state,
      locationController: _locationController,
      descriptionController: _descriptionController,
      phoneController: _phoneController,
      category: _category,
      priority: _priority,
      onCategory: (value) => setState(() => _category = value),
      onPriority: (value) => setState(() => _priority = value),
      onCancel: _resetForm,
      onSubmit: () => _submit(controller),
      onRefreshStatuses: controller.refreshIncidentStatuses,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 980;
        if (wide) {
          return Column(
            children: [
              districtBar,
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 40, child: mapPanel),
                      SizedBox(width: 12),
                      Expanded(flex: 60, child: formPanel),
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
            districtBar,
            Padding(
              padding: EdgeInsets.all(12),
              child: Column(
                children: [
                  SizedBox(height: 540, child: mapPanel),
                  SizedBox(height: 12),
                  formPanel,
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _description() {
    final location = _locationController.text.trim();
    final details = _descriptionController.text.trim();
    if (location.isEmpty) {
      return details;
    }
    if (details.isEmpty) {
      return location;
    }
    return '$location - $details';
  }

  Future<void> _submit(CitizenController controller) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await controller.sendSos(
      category: _category,
      severity: _priority,
      description: _description(),
      reporterPhone: _phoneController.text.trim(),
    );
  }

  void _resetForm() {
    _locationController.clear();
    _descriptionController.clear();
    _phoneController.clear();
    setState(() {
      _category = 'HARASSMENT';
      _priority = 'LOW';
    });
  }
}

class _DistrictStatusBar extends StatelessWidget {
  const _DistrictStatusBar({
    required this.hotspotCount,
    required this.reportCount,
    required this.onLocate,
    required this.onRefresh,
  });

  final int hotspotCount;
  final int reportCount;
  final VoidCallback onLocate;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: TacticalColors.surface,
        border: Border(bottom: BorderSide(color: TacticalColors.border)),
      ),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _StatusNode(
            icon: Icons.radar,
            label: l10n.t('router.riskZones', {'count': hotspotCount}),
            color: TacticalColors.pending,
          ),
          _StatusNode(
            icon: Icons.receipt_long_outlined,
            label: l10n.t('router.deviceReports', {'count': reportCount}),
            color: TacticalColors.low,
          ),
          OutlinedButton.icon(
            onPressed: onLocate,
            icon: Icon(Icons.my_location, size: 17),
            label: Text(l10n.t('router.useLocation')),
          ),
          IconButton(
            onPressed: onRefresh,
            tooltip: l10n.t('router.refresh'),
            icon: Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _StatusNode extends StatelessWidget {
  const _StatusNode({
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
      padding: EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: TacticalColors.background,
        border: Border.all(color: TacticalColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          SizedBox(width: 7),
          Text(label, style: tacticalMono(color: color, fontSize: 10)),
        ],
      ),
    );
  }
}

class _ContextMapPanel extends StatelessWidget {
  const _ContextMapPanel({required this.state});

  final CitizenState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TacticalPanel(
      padding: EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(4, 3, 4, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [TacticalEyebrow(l10n.t('router.map'))],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: SafetyMap(
                    center: state.selectedLocation,
                    hotspots: state.hotspots,
                    showCenterMarker: false,
                    showZoomControls: true,
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: _GridTargetCard(
                    latitude: state.selectedLocation.latitude,
                    longitude: state.selectedLocation.longitude,
                    hotspotCount: state.hotspots.length,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridTargetCard extends StatelessWidget {
  const _GridTargetCard({
    required this.latitude,
    required this.longitude,
    required this.hotspotCount,
  });

  final double latitude;
  final double longitude;
  final int hotspotCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TacticalColors.background.withValues(alpha: 0.94),
        border: Border.all(color: TacticalColors.borderStrong),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TacticalEyebrow(l10n.t('router.currentLocation')),
          SizedBox(height: 5),
          Text(
            '${latitude.toStringAsFixed(6)} / ${longitude.toStringAsFixed(6)}',
            style: tacticalMono(color: TacticalColors.active, fontSize: 12),
          ),
          SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(
                label: l10n.t('router.activeZones', {'count': hotspotCount}),
                compact: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SecureRouterForm extends StatelessWidget {
  const _SecureRouterForm({
    required this.state,
    required this.locationController,
    required this.descriptionController,
    required this.phoneController,
    required this.category,
    required this.priority,
    required this.onCategory,
    required this.onPriority,
    required this.onCancel,
    required this.onSubmit,
    required this.onRefreshStatuses,
  });

  final CitizenState state;
  final TextEditingController locationController;
  final TextEditingController descriptionController;
  final TextEditingController phoneController;
  final String category;
  final String priority;
  final ValueChanged<String> onCategory;
  final ValueChanged<String> onPriority;
  final VoidCallback onCancel;
  final VoidCallback onSubmit;
  final Future<void> Function() onRefreshStatuses;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return TacticalPanel(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TacticalEyebrow(
              l10n.t('router.title'),
              color: TacticalColors.active,
            ),
            SizedBox(height: 6),
            Text(
              l10n.t('router.reportTitle'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 8),
            Text(l10n.t('router.instructions')),
            if (state.incidents.isNotEmpty) ...[
              SizedBox(height: 16),
              CitizenIncidentStatusPanel(
                incidents: state.incidents,
                onRefresh: onRefreshStatuses,
              ),
            ],
            SizedBox(height: 20),
            _FormStepLabel(number: '1', label: l10n.t('router.incidentType')),
            SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: InputDecoration(
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                DropdownMenuItem(
                  value: 'HARASSMENT',
                  child: Text(l10n.t('router.harassment')),
                ),
                DropdownMenuItem(
                  value: 'STALKING',
                  child: Text(l10n.t('router.stalking')),
                ),
                DropdownMenuItem(
                  value: 'OTHER',
                  child: Text(l10n.t('router.brokenStreetlights')),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  onCategory(value);
                }
              },
            ),
            SizedBox(height: 18),
            _FormStepLabel(number: '2', label: l10n.t('router.priority')),
            SizedBox(height: 8),
            _PriorityPicker(selected: priority, onChanged: onPriority),
            SizedBox(height: 18),
            _FormStepLabel(
              number: '3',
              label: l10n.t('router.locationDetails'),
            ),
            SizedBox(height: 8),
            TextField(
              controller: locationController,
              decoration: InputDecoration(
                labelText: l10n.t('router.location'),
                hintText: l10n.t('router.locationHint'),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: descriptionController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: l10n.t('router.notes'),
                hintText: l10n.t('router.notesHint'),
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.t('router.phone'),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            SizedBox(height: 12),
            _CoordinatesReadout(state: state),
            if (state.error != null) ...[
              SizedBox(height: 12),
              _ErrorNotice(message: l10n.error(state.error!)),
            ],
            SizedBox(height: 22),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: state.isReporting ? null : onCancel,
                  icon: Icon(Icons.close, size: 17),
                  label: Text(l10n.t('router.cancel')),
                ),
                SizedBox(width: 10),
                FilledButton.icon(
                  onPressed: state.isReporting ? null : onSubmit,
                  icon: state.isReporting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.check, size: 17),
                  label: Text(l10n.t('router.submit')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormStepLabel extends StatelessWidget {
  const _FormStepLabel({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: TacticalColors.active.withValues(alpha: 0.12),
            border: Border.all(color: TacticalColors.active),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            number,
            style: tacticalMono(color: TacticalColors.active, fontSize: 11),
          ),
        ),
        SizedBox(width: 8),
        TacticalEyebrow(label),
      ],
    );
  }
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _PriorityOption(
          label: l10n.code('LOW'),
          icon: Icons.shield_outlined,
          color: TacticalColors.low,
          selected: selected == 'LOW',
          onTap: () => onChanged('LOW'),
        ),
        _PriorityOption(
          label: l10n.code('MEDIUM'),
          icon: Icons.warning_amber_outlined,
          color: TacticalColors.pending,
          selected: selected == 'MEDIUM',
          onTap: () => onChanged('MEDIUM'),
        ),
        _PriorityOption(
          label: l10n.code('HIGH'),
          icon: Icons.emergency_outlined,
          color: TacticalColors.critical,
          selected: selected == 'HIGH',
          onTap: () => onChanged('HIGH'),
        ),
      ],
    );
  }
}

class _PriorityOption extends StatelessWidget {
  const _PriorityOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 160),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.16)
              : TacticalColors.background,
          border: Border.all(
            color: selected ? color : TacticalColors.border,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17, color: color),
            SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                color: selected ? color : TacticalColors.textMuted,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoordinatesReadout extends StatelessWidget {
  const _CoordinatesReadout({required this.state});

  final CitizenState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: TacticalColors.background,
        border: Border.all(color: TacticalColors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.gps_fixed, color: TacticalColors.active, size: 18),
          SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TacticalEyebrow(l10n.t('router.coordinates')),
                SizedBox(height: 3),
                Text(
                  '${state.selectedLocation.latitude.toStringAsFixed(6)} / '
                  '${state.selectedLocation.longitude.toStringAsFixed(6)}',
                  style: tacticalMono(color: TacticalColors.active),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: TacticalColors.critical.withValues(alpha: 0.1),
        border: Border.all(
          color: TacticalColors.critical.withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(message, style: TextStyle(color: TacticalColors.critical)),
    );
  }
}
