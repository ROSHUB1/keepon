import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_card.dart';
import 'glyph_icon.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message});

  final Glyph icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBadge(size: 52, color: t.primary, child: GlyphIcon(icon, size: 26, color: t.primary)),
          const SizedBox(height: 16),
          Text(title, style: text.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(message, style: text.bodySmall, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
