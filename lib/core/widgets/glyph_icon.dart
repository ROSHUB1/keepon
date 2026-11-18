import 'package:flutter/material.dart';

/// Either a Material [IconData] or the path of a KEEPON icon image (see AppIcons).
typedef Glyph = Object;

/// Draws a KEEPON brand icon (tinted with the theme color) or a Material icon.
/// Icons under assets/icons/color/ keep their own colors (status icons).
class GlyphIcon extends StatelessWidget {
  const GlyphIcon(this.glyph, {super.key, this.size, this.color});

  final Glyph? glyph;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final g = glyph;
    if (g == null) return const SizedBox.shrink();
    if (g is IconData) return Icon(g, size: size, color: color);
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final path = g as String;
    final keepColors = path.contains('/color/');
    final tint = color ?? theme.color ?? Theme.of(context).colorScheme.onSurface;
    return SizedBox(
      width: s,
      height: s,
      child: Image.asset(
        path,
        width: s,
        height: s,
        color: keepColors ? null : tint,
        colorBlendMode: keepColors ? null : BlendMode.srcIn,
        filterQuality: FilterQuality.high,
        excludeFromSemantics: true,
      ),
    );
  }
}
