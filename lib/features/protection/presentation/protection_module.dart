import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/glyph_icon.dart';
import '../../../core/widgets/status_indicator.dart';
import '../../../shared/models/module_status.dart';
import '../../../shared/models/protection_config.dart';
import '../domain/module_info.dart';
import 'module_visuals.dart';

/// One row of the module list: icon, name, description, status, toggle, configure.
class ProtectionModule extends StatelessWidget {
  const ProtectionModule({
    super.key,
    required this.info,
    required this.status,
    required this.enabled,
    required this.toggleable,
    required this.onToggle,
    required this.onConfigure,
  });

  final ModuleInfo info;
  final ModuleStatus status;
  final bool enabled;
  final bool toggleable;
  final ValueChanged<bool> onToggle;
  final VoidCallback onConfigure;

  String get _description => switch (status) {
        ModuleStatus.unsupported => 'This phone does not have the hardware this needs.',
        ModuleStatus.unavailable => 'KEEPON could not reach Android to check this feature.',
        ModuleStatus.permissionRequired => 'Allow notifications so alerts and the Stop button can be shown.',
        _ => info.summary,
      };

  @override
  Widget build(BuildContext context) {
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    final c = status == ModuleStatus.off ? t.textSecondary : status.color;
    return InkWell(
      onTap: onConfigure,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(color: c, child: GlyphIcon(moduleIcon(info.id), size: AppSize.iconInBadge, color: c)),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info.title, style: text.titleSmall),
                        const SizedBox(height: 2),
                        Text(_description, style: text.bodySmall),
                      ],
                    ),
                  ),
                ),
                Switch(value: enabled && toggleable, onChanged: toggleable ? onToggle : null),
              ],
            ),
            Row(
              children: [
                const SizedBox(width: 48),
                StatusIndicator(status: status),
                const Spacer(),
                TextButton(onPressed: onConfigure, child: const Text('Configure')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String sensitivityLabel(MotionSensitivity s) => switch (s) {
      MotionSensitivity.low => 'Low',
      MotionSensitivity.medium => 'Medium',
      MotionSensitivity.high => 'High',
    };
