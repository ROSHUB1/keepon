import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/glyph_icon.dart';
import '../../../shared/models/permission_state.dart';
import '../../../shared/providers/protection_controller.dart';
import '../../../shared/providers/providers.dart';

class _Step {
  const _Step({
    required this.glyph,
    required this.title,
    required this.why,
    required this.how,
    required this.done,
    required this.doneLabel,
    required this.todoLabel,
    required this.actionLabel,
    required this.onAction,
    this.extraLabel,
    this.onExtra,
  });

  final Glyph glyph;
  final String title;
  final String why;
  final List<String> how;
  final bool done;
  final String doneLabel;
  final String todoLabel;
  final String actionLabel;
  final VoidCallback onAction;
  final String? extraLabel;
  final VoidCallback? onExtra;
}

/// One permission per page, with how to reach the Android setting.
/// Status refreshes by itself when the user comes back from Android settings.
class PermissionGuideScreen extends ConsumerStatefulWidget {
  const PermissionGuideScreen({super.key});

  @override
  ConsumerState<PermissionGuideScreen> createState() => _PermissionGuideScreenState();
}

class _PermissionGuideScreenState extends ConsumerState<PermissionGuideScreen> {
  int _index = 0;

  Future<void> _finish() async {
    final s = ref.read(settingsProvider);
    if (!s.onboardingDone) {
      await ref.read(settingsProvider.notifier).update(s.copyWith(onboardingDone: true));
    }
    onboardingGate.value = true;
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  List<_Step> _steps(ProtectionState p, dynamic settings) {
    final bridge = ref.read(bridgeProvider);
    final ctrl = ref.read(protectionProvider.notifier);
    final notif = p.permissions.notifications;
    final loc = p.permissions.location;
    final battery = p.permissions.batteryUnrestricted;
    return [
      _Step(
        glyph: AppIcons.alerts,
        title: 'Allow notifications',
        why: 'KEEPON uses notifications to show alerts and the Stop alarm button.',
        how: [
          'Tap "Allow notifications" below.',
          'On the Android pop-up, tap Allow.',
          'If no pop-up appears, open Android settings > Apps > KEEPON > Notifications and turn them on.',
        ],
        done: notif == PermStatus.granted,
        doneLabel: 'Allowed',
        todoLabel: notif == PermStatus.permanentlyDenied ? 'Blocked' : 'Needs action',
        actionLabel: notif == PermStatus.permanentlyDenied ? 'Open app settings' : 'Allow notifications',
        onAction: () => notif == PermStatus.permanentlyDenied
            ? bridge.openAppSettings()
            : ctrl.requestPermission('notifications'),
      ),
      _Step(
        glyph: AppIcons.charger,
        title: 'Keep protection running',
        why: 'Android can stop background apps to save battery. Set KEEPON to unrestricted so protection keeps going.',
        how: [
          'Tap "Open battery settings".',
          'Choose Unrestricted. Some phones call it "No restrictions" or "Don\'t optimize".',
          'Come back to KEEPON.',
        ],
        done: battery == true,
        doneLabel: 'Unrestricted',
        todoLabel: battery == null ? 'Could not be checked' : 'Needs action',
        actionLabel: 'Open battery settings',
        onAction: () => bridge.openBatterySettings(),
      ),
      _Step(
        glyph: AppIcons.protection,
        title: 'Set a screen lock',
        why: 'With a screen lock, KEEPON can ask for your PIN, pattern or fingerprint before protection is turned off or the alarm is stopped.',
        how: [
          'Tap "Open security settings".',
          'Open Screen lock and choose a PIN, pattern or password.',
          'Add a fingerprint if you like, then come back.',
        ],
        done: p.deviceSecure == true,
        doneLabel: 'Screen lock is set',
        todoLabel: p.deviceSecure == null ? 'Could not be checked' : 'No screen lock',
        actionLabel: 'Open security settings',
        onAction: () => bridge.openSecuritySettings(),
      ),
      if (p.permissions.fullScreenAlarm != null)
        _Step(
          glyph: AppIcons.alerts,
          title: 'Show the alarm on the lock screen',
          why: 'Android needs your permission before an app can open a full-screen alarm while the phone is locked.',
          how: [
            'Tap "Open settings".',
            'Turn on "Allow full-screen notifications" for KEEPON.',
            'Go back to KEEPON.',
          ],
          done: p.permissions.fullScreenAlarm == true,
          doneLabel: 'Allowed',
          todoLabel: 'Needs action',
          actionLabel: 'Open settings',
          onAction: () => bridge.openFullScreenSettings(),
        ),
      _Step(
        glyph: AppIcons.help,
        title: 'Turn on Android theft protection',
        why: 'Android has its own Theft Detection Lock and Remote Lock. They work alongside KEEPON. KEEPON cannot read their state.',
        how: [
          'Tap "Open security settings".',
          'Go to Security & privacy > Device unlock > Theft protection. Names can differ by phone.',
          'Turn on Theft Detection Lock and Remote Lock if your phone offers them.',
          'Come back and tap "I have done this".',
        ],
        done: settings.theftProtectionReviewed == true,
        doneLabel: 'Marked as done',
        todoLabel: 'Cannot be checked',
        actionLabel: 'Open security settings',
        onAction: () => bridge.openSecuritySettings(),
        extraLabel: 'I have done this',
        onExtra: () => ref
            .read(settingsProvider.notifier)
            .update(ref.read(settingsProvider).copyWith(theftProtectionReviewed: true)),
      ),
      _Step(
        glyph: AppIcons.scan,
        title: 'Allow location (optional)',
        why: 'Only used when you tap Update location in Recovery. It is saved on this phone and never sent anywhere.',
        how: [
          'Tap "Allow location".',
          'On the Android pop-up, choose "While using the app".',
          'If no pop-up appears, open Android settings > Apps > KEEPON > Permissions > Location.',
        ],
        done: loc == PermStatus.granted,
        doneLabel: 'Allowed',
        todoLabel: loc == PermStatus.permanentlyDenied ? 'Blocked' : 'Optional',
        actionLabel: loc == PermStatus.permanentlyDenied ? 'Open app settings' : 'Allow location',
        onAction: () => loc == PermStatus.permanentlyDenied
            ? bridge.openAppSettings()
            : ctrl.requestPermission('location'),
      ),
      _Step(
        glyph: AppIcons.scan,
        title: 'Keep recording location after a restart (optional)',
        why: 'During an alarm, KEEPON records the phone\'s location on this phone. After a restart, Android only allows this if location is set to "Allow all the time".',
        how: [
          'Tap "Open app settings".',
          'Open Permissions > Location.',
          'Choose "Allow all the time".',
        ],
        done: p.permissions.backgroundLocation == PermStatus.granted,
        doneLabel: 'Allowed all the time',
        todoLabel: 'Optional',
        actionLabel: 'Open app settings',
        onAction: () => bridge.openAppSettings(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(protectionProvider);
    final settings = ref.watch(settingsProvider);
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;

    final steps = _steps(p, settings);
    final i = _index.clamp(0, steps.length - 1);
    final step = steps[i];
    final last = i == steps.length - 1;
    final chipColor = step.done ? AppColors.success : AppColors.warning;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.s, AppSpace.l, AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text('Step ${i + 1} of ${steps.length}', style: text.labelMedium?.copyWith(color: t.textSecondary))),
                  TextButton(onPressed: _finish, child: Text(context.canPop() ? 'Close' : 'Skip all')),
                ],
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(minHeight: 4, value: (i + 1) / steps.length, backgroundColor: t.border),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: AppSpace.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconBadge(size: 56, color: t.primary, child: GlyphIcon(step.glyph, size: 30, color: t.primary)),
                      const SizedBox(height: AppSpace.l),
                      Text(step.title, style: text.headlineSmall),
                      const SizedBox(height: AppSpace.s),
                      Text(step.why, style: text.bodyLarge?.copyWith(color: t.textSecondary)),
                      const SizedBox(height: AppSpace.m),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: chipColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          step.done ? step.doneLabel : step.todoLabel,
                          style: text.labelMedium?.copyWith(color: chipColor),
                        ),
                      ),
                      const SizedBox(height: AppSpace.l),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('How to', style: text.titleSmall),
                            const SizedBox(height: AppSpace.s),
                            for (var n = 0; n < step.how.length; n++)
                              Padding(
                                padding: const EdgeInsets.only(bottom: AppSpace.s),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 22,
                                      height: 22,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(6)),
                                      child: Text('${n + 1}', style: text.labelSmall?.copyWith(color: t.primary)),
                                    ),
                                    const SizedBox(width: AppSpace.m),
                                    Expanded(child: Text(step.how[n], style: text.bodyMedium)),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!step.done) PrimaryButton(label: step.actionLabel, onPressed: step.onAction),
              if (step.extraLabel != null && !step.done) ...[
                const SizedBox(height: AppSpace.s),
                SecondaryButton(label: step.extraLabel!, onPressed: step.onExtra),
              ],
              const SizedBox(height: AppSpace.s),
              Row(
                children: [
                  if (i > 0) ...[
                    Expanded(child: SecondaryButton(label: 'Back', onPressed: () => setState(() => _index = i - 1))),
                    const SizedBox(width: AppSpace.s),
                  ],
                  Expanded(
                    child: last
                        ? PrimaryButton(label: 'Finish', onPressed: _finish)
                        : (step.done
                            ? PrimaryButton(label: 'Next', onPressed: () => setState(() => _index = i + 1))
                            : SecondaryButton(label: 'Skip for now', onPressed: () => setState(() => _index = i + 1))),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
