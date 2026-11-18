import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utilities/format.dart';
import '../../../core/utilities/snack.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/glyph_icon.dart';
import '../../../shared/models/security_event.dart';
import '../../../shared/providers/protection_controller.dart';
import '../../../shared/providers/providers.dart';

/// Full-screen alarm. Back is disabled while ringing; Stop asks for the device unlock.
class AlarmScreen extends ConsumerStatefulWidget {
  const AlarmScreen({super.key});

  @override
  ConsumerState<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends ConsumerState<AlarmScreen> {
  bool _stopping = false;

  Future<void> _stop() async {
    setState(() => _stopping = true);
    final ok = await ref.read(protectionProvider.notifier).stopAlarm();
    if (!mounted) return;
    setState(() => _stopping = false);
    if (!ok) showKeepOnSnack(context, 'Unlock was not confirmed. The alarm keeps ringing.');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(protectionProvider.select((p) => p.alarmRinging), (prev, next) {
      if (prev == true && !next && mounted) context.go('/home');
    });

    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    final ringing = ref.watch(protectionProvider.select((p) => p.alarmRinging));
    final requireAuth = ref.watch(settingsProvider.select((s) => s.requireAuth));
    final events = ref.watch(eventsProvider);
    SecurityEvent? cause;
    for (final e in events) {
      if (e.alarmTriggered) {
        cause = e;
        break;
      }
    }

    return PopScope(
      canPop: !ringing,
      child: Scaffold(
        backgroundColor: ringing ? AppColors.error.withValues(alpha: t.isDark ? 0.22 : 0.10) : t.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(child: GlyphIcon(AppIcons.alert, size: 72)),
                const SizedBox(height: 20),
                Text(
                  ringing ? 'Alarm is ringing' : 'No alarm is ringing',
                  style: text.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  ringing
                      ? (cause?.description ?? 'KEEPON detected something.')
                      : 'The alarm has stopped.',
                  style: text.bodyLarge,
                  textAlign: TextAlign.center,
                ),
                if (ringing && cause != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${formatTime(cause.timestamp)} · ${cause.type.title}',
                    style: text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ],
                const Spacer(),
                if (ringing) ...[
                  PrimaryButton(
                    label: 'Stop alarm',
                    danger: true,
                    loading: _stopping,
                    onPressed: _stop,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    requireAuth
                        ? 'You will be asked for your PIN, pattern or fingerprint.'
                        : 'Unlock confirmation is turned off in Settings.',
                    style: text.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                ] else
                  PrimaryButton(label: 'Back to KEEPON', onPressed: () => context.go('/home')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
