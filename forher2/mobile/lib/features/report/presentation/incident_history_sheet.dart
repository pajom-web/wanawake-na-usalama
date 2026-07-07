import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/safety_colors.dart';
import '../data/incident_repository.dart';

final incidentHistoryProvider =
    FutureProvider.autoDispose<List<IncidentReportSummary>>((ref) {
  final timer = Timer.periodic(const Duration(seconds: 15), (_) {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);
  return ref.watch(incidentRepositoryProvider).fetchHistory();
});

void showIncidentHistorySheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const IncidentHistorySheet(),
  );
}

class IncidentHistorySheet extends ConsumerWidget {
  const IncidentHistorySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.safetyColors;
    final l10n = context.l10n;
    final history = ref.watch(incidentHistoryProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.56,
      minChildSize: 0.36,
      maxChildSize: 0.86,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
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
              Row(
                children: [
                  Icon(Icons.history_outlined, color: colors.safe),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.incidentHistory,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.retry,
                    onPressed: () => ref.invalidate(incidentHistoryProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: history.when(
                  data: (items) => items.isEmpty
                      ? _EmptyState(message: l10n.noIncidentHistory)
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: colors.outline),
                          itemBuilder: (context, index) {
                            return _IncidentHistoryTile(item: items[index]);
                          },
                        ),
                  error: (error, _) => _ErrorState(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(incidentHistoryProvider),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _IncidentHistoryTile extends StatelessWidget {
  const _IncidentHistoryTile({required this.item});

  final IncidentReportSummary item;

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;
    final l10n = context.l10n;
    final riskOrSeverity =
        item.riskLevel.isNotEmpty ? item.riskLevel : item.severity;
    final subtitle = [
      _categoryLabel(l10n, item.category),
      if (item.status.isNotEmpty) _statusLabel(item.status),
      if (riskOrSeverity.isNotEmpty) riskOrSeverity,
      if (item.occurredAt != null) _formatDate(item.occurredAt!),
    ].join(' - ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (item.isVerified ? colors.safe : colors.warning)
                      .withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.isVerified
                      ? Icons.verified_outlined
                      : Icons.pending_actions_outlined,
                  color: item.isVerified ? colors.safe : colors.warning,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty
                          ? _categoryLabel(l10n, item.category)
                          : item.title,
                      style: TextStyle(
                        color: colors.primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: colors.secondaryText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (item.description.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.description,
              style: TextStyle(color: colors.secondaryText),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            '${l10n.location}: ${item.latitude.toStringAsFixed(5)}, ${item.longitude.toStringAsFixed(5)}',
            style: TextStyle(color: colors.secondaryText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _categoryLabel(AppLocalizations l10n, String category) {
    return switch (category) {
      'harassment' => l10n.harassment,
      'poor_lighting' => l10n.poorLighting,
      'unsafe_street' => l10n.unsafeStreet,
      'deserted_area' => l10n.desertedArea,
      'suspicious_activity' => l10n.suspiciousActivity,
      'HARASSMENT' => l10n.harassment,
      'STALKING' => l10n.suspiciousActivity,
      'SOS' => 'SOS',
      'OTHER' => 'Other',
      _ => category.replaceAll('_', ' '),
    };
  }
}

String _statusLabel(String status) {
  final words = status.toLowerCase().split('_');
  return words.map((word) {
    if (word.isEmpty) return word;
    return '${word[0].toUpperCase()}${word.substring(1)}';
  }).join(' ');
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;
    return Center(
      child: Text(
        message,
        style:
            TextStyle(color: colors.secondaryText, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;
    final l10n = context.l10n;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, color: colors.warning),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.secondaryText),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int input) => input.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}';
}
