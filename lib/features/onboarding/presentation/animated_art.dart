import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/glyph_icon.dart';

/// Plays a Lottie animation from assets/animations/. If the file is missing,
/// shows a gently pulsing KEEPON icon instead, so the screen always works.
class AnimatedArt extends StatelessWidget {
  const AnimatedArt({super.key, required this.asset, required this.fallback, this.size = 200});

  final String asset;
  final Glyph fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        asset,
        fit: BoxFit.contain,
        repeat: true,
        errorBuilder: (context, error, stackTrace) => _PulsingIcon(glyph: fallback),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon({required this.glyph});

  final Glyph glyph;

  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = KeepOnTokens.of(context);
    return Center(
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.94, end: 1.06).animate(
          CurvedAnimation(parent: _c, curve: Curves.easeInOut),
        ),
        child: IconBadge(
          size: 112,
          color: t.primary,
          child: GlyphIcon(widget.glyph, size: 60, color: t.primary),
        ),
      ),
    );
  }
}
