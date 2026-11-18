import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_card.dart';
import '../../../shared/models/permission_state.dart';
import '../../../shared/providers/protection_controller.dart';
import '../../../shared/providers/providers.dart';

class _Item {
  const _Item(this.title, this.subtitle, this.done, this.action, this.onTap);
  final String title;
  final String subtitle;
  final bool done;
  final String action;
  final VoidCallback onTap;
}

/// "Finish setup" card. Disappears when everything KEEPON can check is ready.
class SetupChecklist extends ConsumerWidget {
  const SetupChecklist({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(protectionProvider);
    final settings = ref.watch(settingsProvider);
    final bridge = ref.read(bridgeProvider);
    final ctrl = ref.read(protectionProvider.notifier);
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;

    final notif = p.permissions.notifications;
    final battery = p.permissions.batteryUnrestricted;

    final items = <_Item>[
      _Item(
        'Notifications',
        'Needed to show alerts and the alarm Stop button.',
        notif == PermStatus.granted,
        'Allow',
        () {
          if (notif == PermStatus.permanentlyDenied) {
            bridge.openAppSettings();
          } else {
            ctrl.requestPermission('notifications');
          }
        },
      ),
      if (battery != null)
        _Item(
          'Battery use',
          'Set KEEPON to unrestricted so Android keeps protection running.',
          battery,
          'Open settings',
          () => bridge.openBatterySettings(),
        ),
      if (p.deviceSecure != null)
        _Item(
          'Screen lock',
          'A PIN, pattern or fingerprint lets KEEPON ask for unlock before protection is turned off.',
          p.deviceSecure == true,
          'Open settings',
          () => bridge.openSecuritySettings(),
        ),
      if (p.permissions.fullScreenAlarm != null)
        _Item(
          'Alarm over the lock screen',
          'Allow full-screen notifications so the alarm screen can appear when the phone is locked.',
          p.permissions.fullScreenAlarm == true,
          'Open settings',
          () => bridge.openFullScreenSettings(),
        ),
      _Item(
        'Android theft protection',
        'Turn on Theft Detection Lock and Remote Lock in Android settings. KEEPON cannot read them, so this is marked done once you open them.',
        settings.theftProtectionReviewed,
        'Review',
        () async {
          await bridge.openSecuritySettings();
          await ref.read(settingsProvider.notifier).update(settings.copyWith(theftProtectionReviewed: true));
        },
      ),
    ];

    final done = items.where((i) => i.done).length;
    if (done == items.length) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Row(
                children: [
                  Expanded(child: Text('Finish setup', style: text.titleSmall)),
                  Text('$done of ${items.length} ready', style: text.bodySmall),
                  TextButton(onPressed: () => context.push('/setup'), child: const Text('Guide')),
                ],
              ),
            ),
            for (final item in items) ...[
              const Divider(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(
                        item.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        size: 20,
                        color: item.done ? AppColors.success : t.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item.title, style: text.titleSmall),
                          Text(item.subtitle, style: text.bodySmall),
                        ],
                      ),
                    ),
                    if (!item.done) TextButton(onPressed: item.onTap, child: Text(item.action)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
