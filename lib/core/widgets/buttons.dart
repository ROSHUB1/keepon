import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'glyph_icon.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.danger = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Glyph? icon;
  final bool loading;
  final bool expanded;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final t = KeepOnTokens.of(context);
    final enabled = onPressed != null && !loading;
    final fg = enabled ? Colors.white : t.textSecondary;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        height: AppSize.button,
        width: expanded ? double.infinity : null,
        child: Material(
          color: enabled ? (danger ? AppColors.error : t.primaryDeep) : t.border,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.control),
            onTap: enabled ? onPressed : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              child: Row(
                mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (loading)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  else if (icon != null)
                    GlyphIcon(icon, color: fg, size: 20),
                  if (loading || icon != null) const SizedBox(width: AppSpace.s),
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.danger = false,
    this.expanded = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final Glyph? icon;
  final bool danger;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final t = KeepOnTokens.of(context);
    final enabled = onPressed != null;
    final color = !enabled ? t.textSecondary : (danger ? AppColors.error : t.primary);
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: SizedBox(
        height: AppSize.button,
        width: expanded ? double.infinity : null,
        child: Material(
          color: t.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
            side: BorderSide(color: enabled ? color.withValues(alpha: 0.55) : t.border),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.control),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl),
              child: Row(
                mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    GlyphIcon(icon, color: color, size: 20),
                    const SizedBox(width: AppSpace.s),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
