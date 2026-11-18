import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Flat surface with a hairline border. The one container used across the app.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpace.l),
    this.onTap,
    this.color,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final t = KeepOnTokens.of(context);
    final content = Padding(padding: padding, child: child);
    return Material(
      color: color ?? t.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.card),
        side: BorderSide(color: borderColor ?? t.border),
      ),
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// Rounded-square badge holding an icon. Used by every list row.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.child, required this.color, this.size = AppSize.iconBadge});

  final Widget child;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: child,
    );
  }
}
