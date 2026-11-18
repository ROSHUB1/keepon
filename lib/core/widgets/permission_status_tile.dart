import 'package:flutter/material.dart';

import '../../shared/models/permission_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'glyph_icon.dart';

class PermissionStatusTile extends StatelessWidget {
  const PermissionStatusTile({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.status,
    this.actionLabel,
    this.onAction,
  });

  final Glyph icon;
  final String title;
  final String description;
  final PermStatus status;
  final String? actionLabel;
  final VoidCallback? onAction;

  (String, Color) get _chip => switch (status) {
        PermStatus.granted => ('Allowed', AppColors.success),
        PermStatus.denied => ('Not allowed', AppColors.warning),
        PermStatus.permanentlyDenied => ('Blocked', AppColors.error),
        PermStatus.unknown => ('Unknown', AppColors.textSecondary),
      };

  @override
  Widget build(BuildContext context) {
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    final (label, color) = _chip;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(color: t.primary, child: GlyphIcon(icon, size: AppSize.iconInBadge, color: t.primary)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: text.titleSmall)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(label, style: text.labelSmall?.copyWith(color: color)),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(description, style: text.bodySmall),
                if (actionLabel != null && status != PermStatus.granted)
                  TextButton(
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(48, 40), alignment: Alignment.centerLeft),
                    onPressed: onAction,
                    child: Text(actionLabel!),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
