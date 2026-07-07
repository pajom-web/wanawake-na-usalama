import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/safety_colors.dart';
import '../data/safety_tip_repository.dart';
import '../domain/safety_tip.dart';

final safetyTipsProvider = FutureProvider.autoDispose<List<SafetyTip>>((ref) {
  return ref.watch(safetyTipRepositoryProvider).fetchTips();
});

void showSafetyTipsSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const SafetyTipsSheet(),
  );
}

class SafetyTipsSheet extends ConsumerWidget {
  const SafetyTipsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.safetyColors;
    final l10n = context.l10n;
    final tips = ref.watch(safetyTipsProvider);

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
                  Icon(Icons.health_and_safety_outlined, color: colors.safe),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.safetyTips,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          l10n.adminUpdatedTips,
                          style: TextStyle(
                            color: colors.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.retry,
                    onPressed: () => ref.invalidate(safetyTipsProvider),
                    icon: const Icon(Icons.refresh),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: tips.when(
                  data: (items) => items.isEmpty
                      ? _EmptyState(message: l10n.noSafetyTips)
                      : ListView.separated(
                          controller: scrollController,
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              Divider(color: colors.outline),
                          itemBuilder: (context, index) {
                            return _SafetyTipTile(tip: items[index]);
                          },
                        ),
                  error: (error, _) => _ErrorState(
                    message: error.toString(),
                    onRetry: () => ref.invalidate(safetyTipsProvider),
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

class _SafetyTipTile extends StatelessWidget {
  const _SafetyTipTile({required this.tip});

  final SafetyTip tip;

  @override
  Widget build(BuildContext context) {
    final colors = context.safetyColors;
    final meta = [
      if (tip.category.isNotEmpty) tip.category,
      if (tip.updatedAt != null) _formatDate(tip.updatedAt!),
    ].join(' - ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: colors.safe.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.tips_and_updates_outlined, color: colors.safe),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tip.title,
                  style: TextStyle(
                    color: colors.primaryText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    meta,
                    style: TextStyle(
                      color: colors.secondaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  tip.body,
                  style: TextStyle(color: colors.secondaryText, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
