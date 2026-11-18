import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utilities/format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glyph_icon.dart';
import '../../../core/widgets/screen_layout.dart';
import '../../../shared/models/security_event.dart';
import '../../../shared/providers/protection_controller.dart';
import '../../../shared/providers/providers.dart';
import 'activity_timeline_item.dart';

class ActivityScreen extends ConsumerWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    final all = ref.watch(eventsProvider);
    final filter = ref.watch(activityFilterProvider);
    final storageError = ref.watch(storageErrorProvider);
    final refreshing = ref.watch(protectionProvider.select((p) => p.refreshing));
    final shown = all.where((e) => e.matches(filter)).toList();

    // Group by day (events are sorted newest first).
    final groups = <String, List<SecurityEvent>>{};
    for (final e in shown) {
      groups.putIfAbsent(dayLabel(e.timestamp), () => []).add(e);
    }

    return ScreenList(
      children: [
        ScreenHeader(
          title: 'Activity History',
          subtitle: '${all.length} ${all.length == 1 ? 'event' : 'events'} recorded on this device',
          trailing: all.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear history',
                  icon: GlyphIcon(AppIcons.delete, size: 22, color: t.textSecondary),
                  onPressed: () async {
                    final ok = await showConfirmation(
                      context,
                      title: 'Clear history?',
                      message: 'All recorded events will be deleted from this device. This cannot be undone.',
                      confirmLabel: 'Clear',
                      destructive: true,
                    );
                    if (ok) await ref.read(eventsProvider.notifier).clear();
                  },
                ),
        ),
        RefreshBar(active: refreshing),
        if (storageError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppCard(
              color: AppColors.error.withValues(alpha: 0.10),
              borderColor: AppColors.error.withValues(alpha: 0.3),
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(storageError, style: text.bodyMedium)),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in ActivityFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: AppChip(
                    label: f.label,
                    selected: f == filter,
                    onTap: () => ref.read(activityFilterProvider.notifier).state = f,
                  ),
                ),
            ],
          ),
        ),
        if (shown.isEmpty)
          all.isEmpty
              ? EmptyState(
                  icon: AppIcons.history,
                  title: 'No activity recorded yet.',
                  message: 'Detected security events will appear here.',
                )
              : EmptyState(
                  icon: AppIcons.filter,
                  title: 'Nothing in this filter.',
                  message: 'Try another filter to see other recorded events.',
                ),
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 20, 0, 8),
            child: Text(entry.key, style: text.labelMedium?.copyWith(color: t.textSecondary)),
          ),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  if (i > 0) const Divider(indent: 64),
                  ActivityTimelineItem(
                    event: entry.value[i],
                    onTap: () => context.push('/event/${entry.value[i].id}'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
