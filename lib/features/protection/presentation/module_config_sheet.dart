import '../../../core/widgets/glyph_icon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utilities/snack.dart';
import '../../../core/widgets/status_indicator.dart';
import '../../../shared/models/protection_config.dart';
import '../../../shared/providers/protection_controller.dart';
import '../domain/module_info.dart';
import 'module_visuals.dart';
import 'protection_module.dart';

Future<void> showModuleConfigSheet(BuildContext context, ModuleId id) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ModuleConfigSheet(id: id),
  );
}

class ModuleConfigSheet extends ConsumerWidget {
  const ModuleConfigSheet({super.key, required this.id});

  final ModuleId id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    final p = ref.watch(protectionProvider);
    final ctrl = ref.read(protectionProvider.notifier);
    final info = moduleInfo(id);
    final cfg = p.config.module(id);
    final supported = p.moduleSupported(id);
    final status = p.statusOf(id);

    Widget block(String title, String body) => Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: text.titleSmall),
              const SizedBox(height: 4),
              Text(body, style: text.bodyMedium),
            ],
          ),
        );

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      decoration: BoxDecoration(
        color: t.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: t.divider, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  GlyphIcon(moduleIcon(id), color: t.primary, size: 24),
                  const SizedBox(width: 10),
                  Expanded(child: Text(info.title, style: text.titleLarge)),
                  StatusIndicator(status: status),
                ],
              ),
              const SizedBox(height: 6),
              Text(info.summary, style: text.bodyMedium),
              if (!supported)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'This phone does not report the hardware this feature needs, so it cannot be turned on.',
                    style: text.bodyMedium,
                  ),
                ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Enable this module'),
                subtitle: Text(
                  p.armed
                      ? 'Changes apply to the running service immediately.'
                      : 'It starts working when you turn protection on.',
                ),
                value: cfg.enabled && supported,
                onChanged: supported
                    ? (v) async {
                        final err = await ctrl.setModule(id, cfg.copyWith(enabled: v));
                        if (err != null && context.mounted) showKeepOnSnack(context, err);
                      }
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Sound the alarm'),
                subtitle: const Text('When off, the event is only recorded in Activity.'),
                value: cfg.alarmEnabled,
                onChanged: supported ? (v) => ctrl.setModule(id, cfg.copyWith(alarmEnabled: v)) : null,
              ),
              if (id == ModuleId.motion) ...[
                const SizedBox(height: 8),
                Text('Sensitivity', style: text.titleSmall),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<MotionSensitivity>(
                    showSelectedIcon: false,
                    segments: [
                      for (final s in MotionSensitivity.values)
                        ButtonSegment(value: s, label: Text(sensitivityLabel(s))),
                    ],
                    selected: {cfg.sensitivity},
                    onSelectionChanged: (v) => ctrl.setModule(id, cfg.copyWith(sensitivity: v.first)),
                  ),
                ),
              ],
              block('How it works', info.howItWorks),
              block('Limitations', info.limitations),
              block('Permissions', info.permissionNote),
            ],
          ),
        ),
      ),
    );
  }
}
