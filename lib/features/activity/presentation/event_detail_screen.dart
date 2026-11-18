import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utilities/format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/device_info_row.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/glyph_icon.dart';
import '../../../core/widgets/screen_layout.dart';
import '../../../shared/models/security_event.dart';
import '../../../shared/providers/providers.dart';
import 'event_visuals.dart';

class EventDetailScreen extends ConsumerWidget {
  const EventDetailScreen({super.key, required this.eventId});

  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(eventsProvider);
    SecurityEvent? event;
    for (final e in events) {
      if (e.id == eventId) event = e;
    }
    if (event == null) {
      return SubPage(
        title: 'Event details',
        children: [
          EmptyState(
            icon: AppIcons.help,
            title: 'Event not found',
            message: 'This event is no longer in the history.',
          ),
        ],
      );
    }
    final e = event;
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    final color = eventColor(e);
    final sec = e.timestamp.second.toString().padLeft(2, '0');
    return SubPage(
      title: 'Event details',
      children: [
        AppCard(
          child: Row(
            children: [
              IconBadge(size: 48, color: color, child: GlyphIcon(eventIcon(e.type), size: 26, color: color)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.type.title, style: text.titleMedium),
                    Text(severityLabel(e.severity), style: text.labelMedium?.copyWith(color: eventTextColor(e, t.isDark))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              DeviceInformationRow(label: 'Date', value: formatDate(e.timestamp)),
              const Divider(),
              DeviceInformationRow(label: 'Time', value: '${formatTime(e.timestamp)}:$sec'),
              const Divider(),
              DeviceInformationRow(label: 'Security status', value: e.status.isEmpty ? 'Recorded' : e.status),
              const Divider(),
              DeviceInformationRow(label: 'Alarm triggered', value: e.alarmTriggered ? 'Yes' : 'No'),
              const Divider(),
              DeviceInformationRow(label: 'Event ID', value: e.id),
            ],
          ),
        ),
        const SizedBox(height: 12),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Description', style: text.labelMedium?.copyWith(color: t.textSecondary)),
              const SizedBox(height: 4),
              Text(e.description, style: text.bodyLarge),
              const SizedBox(height: 16),
              Text('Detection result', style: text.labelMedium?.copyWith(color: t.textSecondary)),
              const SizedBox(height: 4),
              Text(e.detection.isEmpty ? 'No additional detail was recorded.' : e.detection, style: text.bodyLarge),
            ],
          ),
        ),
      ],
    );
  }
}
