import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/glyph_icon.dart';
import '../../../shared/models/security_event.dart';

Glyph eventIcon(EventType t) => switch (t) {
      EventType.motionDetected => AppIcons.motion,
      EventType.chargerDisconnected => AppIcons.charger,
      EventType.headphonesDisconnected => AppIcons.headphones,
      EventType.simStateChanged => AppIcons.sim,
      EventType.protectionActivated => AppIcons.protection,
      EventType.protectionDeactivated => AppIcons.protection,
      EventType.serviceInterrupted => AppIcons.refresh,
      EventType.permissionUnavailable => AppIcons.alerts,
      EventType.alarmCancelled => AppIcons.protection,
      EventType.alarmStopped => AppIcons.protection,
      EventType.connectivityLost => AppIcons.network,
      EventType.pinFailed => AppIcons.alerts,
      EventType.tamperDetected => AppIcons.alert,
    };

Color eventColor(SecurityEvent e) {
  if (e.type == EventType.protectionActivated ||
      e.type == EventType.alarmCancelled ||
      e.type == EventType.alarmStopped) {
    return AppColors.success;
  }
  return switch (e.severity) {
    EventSeverity.critical => AppColors.error,
    EventSeverity.attention => AppColors.warning,
    EventSeverity.info => AppColors.primary,
  };
}

Color eventTextColor(SecurityEvent e, bool dark) {
  if (dark) {
    return switch (eventColor(e)) {
      AppColors.success => const Color(0xFF4CC38A),
      AppColors.error => const Color(0xFFEF8A8A),
      AppColors.warning => const Color(0xFFE8B25A),
      _ => const Color(0xFF8DB4F5),
    };
  }
  return switch (eventColor(e)) {
    AppColors.success => const Color(0xFF1B7A52),
    AppColors.error => const Color(0xFFB03F3F),
    AppColors.warning => const Color(0xFF9A6A12),
    _ => AppColors.primaryDeep,
  };
}

String severityLabel(EventSeverity s) => switch (s) {
      EventSeverity.critical => 'Critical alert',
      EventSeverity.attention => 'Needs attention',
      EventSeverity.info => 'Information',
    };
