import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_card.dart';
import 'glyph_icon.dart';

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
  });

  final Glyph icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    final c = iconColor ?? t.primary;
    final enabled = onTap != null || trailing != null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              IconBadge(color: c, child: GlyphIcon(icon, size: AppSize.iconInBadge, color: c)),
              const SizedBox(width: 12),
              Expanded(
                child: Opacity(
                  opacity: enabled ? 1 : 0.9,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: text.titleSmall),
                      if (subtitle != null) Text(subtitle!, style: text.bodySmall),
                    ],
                  ),
                ),
              ),
              if (trailing != null) trailing!,
              if (trailing == null && onTap != null)
                Icon(Icons.chevron_right_rounded, color: t.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// One card holding rows separated by hairline dividers.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(indent: 64));
      rows.add(children[i]);
    }
    return AppCard(padding: EdgeInsets.zero, child: Column(children: rows));
  }
}
