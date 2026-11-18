import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utilities/format.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/glyph_icon.dart';
import '../../../shared/models/security_event.dart';
import 'event_visuals.dart';

class ActivityTimelineItem extends StatelessWidget {
  const ActivityTimelineItem({super.key, required this.event, this.onTap});

  final SecurityEvent event;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    final color = eventColor(event);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(color: color, child: GlyphIcon(eventIcon(event.type), size: AppSize.iconInBadge, color: color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: Text(event.type.title, style: text.titleSmall)),
                      const SizedBox(width: 8),
                      Text(formatTime(event.timestamp), style: text.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(event.description, style: text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (event.status.isNotEmpty)
                    Text(event.status, style: text.labelSmall?.copyWith(color: t.textSecondary)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        severityLabel(event.severity),
                        style: text.labelSmall?.copyWith(color: eventTextColor(event, t.isDark)),
                      ),
                      if (event.alarmTriggered) ...[
                        const SizedBox(width: 6),
                        Text('· Alarm sounded', style: text.labelSmall?.copyWith(color: t.textSecondary)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
