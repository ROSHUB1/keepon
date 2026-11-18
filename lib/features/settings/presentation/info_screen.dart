import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/screen_layout.dart';
import '../domain/info_content.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key, required this.topic});

  final String topic;

  @override
  Widget build(BuildContext context) {
    final page = infoPages[topic];
    if (page == null) {
      return const SubPage(
        title: 'Information',
        children: [
          EmptyState(icon: Icons.info_outline_rounded, title: 'Page not found', message: 'This page does not exist.'),
        ],
      );
    }
    final text = Theme.of(context).textTheme;
    return SubPage(
      title: page.title,
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final p in page.paragraphs)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(p, style: text.bodyLarge),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
