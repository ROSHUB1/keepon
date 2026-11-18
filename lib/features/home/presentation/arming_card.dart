import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';

/// Shows the 10 second arming delay of motion detection, with a Cancel button.
class ArmingCard extends StatefulWidget {
  const ArmingCard({super.key, required this.until, required this.onCancel});

  final DateTime until;
  final VoidCallback onCancel;

  @override
  State<ArmingCard> createState() => _ArmingCardState();
}

class _ArmingCardState extends State<ArmingCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final left = widget.until.difference(DateTime.now());
    if (left <= Duration.zero) return const SizedBox.shrink();
    final seconds = (left.inMilliseconds / 1000).ceil();
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    return AppCard(
      color: t.primarySoft,
      borderColor: t.primary.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Motion detection arms in ${seconds}s', style: text.titleSmall),
                    Text('Put the phone down now. Moving it after this will sound the alarm.', style: text.bodySmall),
                  ],
                ),
              ),
              TextButton(onPressed: widget.onCancel, child: const Text('Cancel')),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: (left.inMilliseconds / 10000).clamp(0.0, 1.0),
              backgroundColor: t.surface,
            ),
          ),
        ],
      ),
    );
  }
}
