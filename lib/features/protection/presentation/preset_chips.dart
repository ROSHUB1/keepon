import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utilities/snack.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../shared/providers/protection_controller.dart';
import '../domain/presets.dart';

/// One-tap module presets. Picking one never turns protection on by itself.
class PresetChips extends ConsumerWidget {
  const PresetChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(protectionProvider);
    final ctrl = ref.read(protectionProvider.notifier);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final preset in protectionPresets)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: AppChip(
                label: preset.title,
                selected: preset.matches(p.config),
                onTap: () async {
                  final err = await ctrl.applyPreset(preset);
                  if (!context.mounted) return;
                  showKeepOnSnack(context, err ?? '${preset.title}: ${preset.subtitle}');
                },
              ),
            ),
        ],
      ),
    );
  }
}
