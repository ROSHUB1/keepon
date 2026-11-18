import 'package:flutter/material.dart';

import '../../shared/models/module_status.dart';
import '../theme/app_theme.dart';

/// Small tinted label showing a module/protection status.
class StatusIndicator extends StatelessWidget {
  const StatusIndicator({super.key, required this.status});

  final ModuleStatus status;

  @override
  Widget build(BuildContext context) {
    final dark = KeepOnTokens.of(context).isDark;
    return Semantics(
      label: 'Status: ${status.label}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: status.color.withValues(alpha: dark ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          status.label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: status.foreground(dark)),
        ),
      ),
    );
  }
}
