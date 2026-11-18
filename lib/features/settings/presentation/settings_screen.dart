import '../../../core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utilities/snack.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/device_info_row.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_chip.dart';
import '../../../core/widgets/permission_status_tile.dart';
import '../../../core/widgets/screen_layout.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../../shared/models/app_settings.dart';
import '../../../shared/models/permission_state.dart';
import '../../../shared/models/protection_config.dart';
import '../../../shared/providers/protection_controller.dart';
import '../../../shared/providers/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final p = ref.watch(protectionProvider);
    final ctrl = ref.read(protectionProvider.notifier);
    final bridge = ref.read(bridgeProvider);
    final text = Theme.of(context).textTheme;
    final alarm = p.config.alarm;
    final d = p.device;

    Future<void> updateSettings(ApplicationSettings settingsNew) async {
      await ref.read(settingsProvider.notifier).update(settingsNew);
      await ctrl.syncIfArmed();
    }

    Future<void> requestOrOpen(String name, PermStatus status) async {
      if (status == PermStatus.permanentlyDenied) {
        await bridge.openAppSettings();
      } else {
        await ctrl.requestPermission(name);
      }
    }

    final accelerometer = d == null ? PermStatus.unknown : (d.hasAccelerometer ? PermStatus.granted : PermStatus.denied);
    final battery = p.permissions.batteryUnrestricted;

    return SubPage(
      title: 'Settings',
      children: [
        const SectionHeader(title: 'Appearance'),
        AppCard(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {settings.themeMode},
              onSelectionChanged: (v) => updateSettings(settings.copyWith(themeMode: v.first)),
            ),
          ),
        ),
        const SectionHeader(title: 'Notifications'),
        SettingsGroup(
          children: [
            SettingsTile(
              icon: AppIcons.alerts,
              title: 'Security notifications',
              subtitle: 'Show a notification for each detected event',
              trailing: Switch(
                value: settings.notifySecurity,
                onChanged: (v) => updateSettings(settings.copyWith(notifySecurity: v)),
              ),
            ),
            SettingsTile(
              icon: AppIcons.alerts,
              title: 'Alarm notifications',
              subtitle: 'Show a "Stop alarm" notification while the alarm rings',
              trailing: Switch(
                value: settings.notifyAlarm,
                onChanged: (v) => updateSettings(settings.copyWith(notifyAlarm: v)),
              ),
            ),
            const SettingsTile(
              icon: AppIcons.live,
              title: 'Monitoring status',
              subtitle: 'While protection is on, Android requires a persistent notification. It cannot be hidden.',
            ),
          ],
        ),
        const SectionHeader(title: 'Security'),
        SettingsGroup(
          children: [
            SettingsTile(
              icon: AppIcons.protection,
              title: 'Require unlock to turn off',
              subtitle: p.deviceSecure == false
                  ? 'Set a screen lock in Android settings first. Without one this cannot be enforced.'
                  : 'Asks for your PIN, pattern or fingerprint before turning protection off or stopping the alarm.',
              trailing: Switch(
                value: settings.requireAuth,
                onChanged: (v) async {
                  if (!v) {
                    final ok = await ctrl.authorize('Unlock to stop asking for confirmation.');
                    if (!ok) return;
                  }
                  await updateSettings(settings.copyWith(requireAuth: v));
                },
              ),
            ),
            SettingsTile(
              icon: AppIcons.help,
              title: 'Android theft protection',
              subtitle: 'Settings > Security & privacy > Device unlock > Theft protection',
              onTap: () async {
                await bridge.openSecuritySettings();
                await updateSettings(settings.copyWith(theftProtectionReviewed: true));
              },
            ),
          ],
        ),
        const SectionHeader(title: 'Response'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Entry delay', style: text.titleSmall),
              const SizedBox(height: 4),
              Text(
                'After a trigger, the alarm waits this long. Unlocking the phone in time cancels it.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in const [(0, 'Off'), (5, '5 s'), (10, '10 s'), (15, '15 s')])
                    AppChip(
                      label: o.$2,
                      selected: alarm.entryDelaySeconds == o.$1,
                      onTap: () => ctrl.setAlarm(alarm.copyWith(entryDelaySeconds: o.$1)),
                    ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ignore events while I use the phone'),
                subtitle: const Text('Off by default. When on, motion, charger and headphone events are ignored while the screen is on and unlocked, so the alarm will NOT sound if someone grabs the phone while it is in use. A removed SIM always counts.'),
                value: alarm.ignoreWhileUnlocked,
                onChanged: (v) => ctrl.setAlarm(alarm.copyWith(ignoreWhileUnlocked: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Lock the phone when an alarm triggers'),
                subtitle: Text(
                  alarm.lockOnAlarm && !p.adminActive
                      ? 'Needs device admin. Tap the switch off and on to open Android\'s permission screen again.'
                      : 'Uses Android device admin to lock the screen. With device admin on, 3 wrong lock-screen codes also start the alarm while protection is on.',
                ),
                value: alarm.lockOnAlarm,
                onChanged: (v) => ctrl.setLockOnAlarm(v),
              ),
              if (p.adminActive)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () async {
                      final ok = await ctrl.removeAdmin();
                      if (!ok && context.mounted) showKeepOnSnack(context, 'Unlock was not confirmed. Device admin stays on.');
                    },
                    child: const Text('Remove device admin (needed before uninstalling)'),
                  ),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Alarm if KEEPON is stopped unexpectedly'),
                subtitle: const Text('A watchdog restarts protection if it is killed while on. This sounds the alarm too, so it can cause false alarms when Android ends background apps. Off by default.'),
                value: alarm.tamperAlarm,
                onChanged: (v) => ctrl.setAlarm(alarm.copyWith(tamperAlarm: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Record location during an alarm'),
                subtitle: const Text('Saved on this phone only, encrypted. Nothing is sent anywhere.'),
                value: alarm.trackLocation,
                onChanged: (v) => ctrl.setAlarm(alarm.copyWith(trackLocation: v)),
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Alarm'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sound', style: text.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final o in const [
                    (AlarmSound.siren, 'Security siren'),
                    (AlarmSound.alarm, 'Phone alarm'),
                    (AlarmSound.ringtone, 'Ringtone'),
                    (AlarmSound.notification, 'Alert tone'),
                  ])
                    AppChip(
                      label: o.$2,
                      selected: alarm.sound == o.$1,
                      onTap: () => ctrl.setAlarm(alarm.copyWith(sound: o.$1)),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                alarm.sound == AlarmSound.siren
                    ? 'KEEPON\'s own high-pitched electronic warning. It plays on the phone speaker even if headphones are connected, and uses your alarm volume below.'
                    : 'Uses a sound from Android.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 16),
              Text('Volume: ${alarm.volume}%', style: text.titleSmall),
              Slider(
                min: 10,
                max: 100,
                divisions: 9,
                value: alarm.volume.toDouble().clamp(10, 100),
                label: '${alarm.volume}%',
                onChanged: (v) => ctrl.setAlarm(alarm.copyWith(volume: v.round())),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Vibration'),
                value: alarm.vibrate,
                onChanged: (v) => ctrl.setAlarm(alarm.copyWith(vibrate: v)),
              ),
              const SizedBox(height: 4),
              Text('Alarm behavior', style: text.titleSmall),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 30, label: Text('30 s')),
                    ButtonSegment(value: 60, label: Text('1 min')),
                    ButtonSegment(value: 300, label: Text('5 min')),
                    ButtonSegment(value: 0, label: Text('Manual')),
                  ],
                  selected: {alarm.autoStopSeconds},
                  onSelectionChanged: (v) => ctrl.setAlarm(alarm.copyWith(autoStopSeconds: v.first)),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                alarm.autoStopSeconds == 0
                    ? 'The alarm rings until you stop it.'
                    : 'The alarm stops by itself, or earlier when you stop it.',
                style: text.bodySmall,
              ),
              const SizedBox(height: 14),
              SecondaryButton(
                label: 'Test full alarm (protection must be on)',
                icon: Icons.warning_amber_rounded,
                onPressed: () async {
                  final err = await ref.read(bridgeProvider).simulateTrigger();
                  if (context.mounted) {
                    showKeepOnSnack(context, err ?? 'Test started. The alarm screen should appear.');
                  }
                },
              ),
              const SizedBox(height: 8),
              SecondaryButton(
                label: 'Test alarm (4 seconds)',
                icon: Icons.play_arrow_rounded,
                onPressed: () async {
                  final err = await ctrl.testAlarm();
                  if (err != null && context.mounted) showKeepOnSnack(context, 'Alarm failed: $err');
                },
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'Permissions'),
        SettingsGroup(
          children: [
            PermissionStatusTile(
              icon: AppIcons.alerts,
              title: 'Notifications',
              description: 'Needed to show alerts and the alarm Stop button.',
              status: p.permissions.notifications,
              actionLabel: p.permissions.notifications == PermStatus.permanentlyDenied ? 'Open Android settings' : 'Allow',
              onAction: () => requestOrOpen('notifications', p.permissions.notifications),
            ),
            PermissionStatusTile(
              icon: AppIcons.scan,
              title: 'Location',
              description: 'Only used when you tap "Update location now" in Device Recovery.',
              status: p.permissions.location,
              actionLabel: p.permissions.location == PermStatus.permanentlyDenied ? 'Open Android settings' : 'Allow',
              onAction: () => requestOrOpen('location', p.permissions.location),
            ),
            PermissionStatusTile(
              icon: AppIcons.motion,
              title: 'Motion sensor',
              description: accelerometer == PermStatus.granted
                  ? 'This phone has an accelerometer.'
                  : 'No accelerometer was reported, so motion detection is unavailable.',
              status: accelerometer,
            ),
            PermissionStatusTile(
              icon: Icons.battery_saver_rounded,
              title: 'Background execution',
              description: battery == null
                  ? 'Battery restriction status could not be read.'
                  : (battery
                      ? 'Android is not limiting KEEPON in the background.'
                      : 'Android may limit KEEPON in the background and stop protection.'),
              status: battery == null ? PermStatus.unknown : (battery ? PermStatus.granted : PermStatus.denied),
              actionLabel: 'Open battery settings',
              onAction: () => bridge.openBatterySettings(),
            ),
            SettingsTile(
              icon: AppIcons.help,
              title: 'Permission guide',
              subtitle: 'Step-by-step help for every permission',
              onTap: () => context.push('/setup'),
            ),
            SettingsTile(
              icon: AppIcons.settings,
              title: 'Android app settings',
              subtitle: 'Review every permission for KEEPON',
              onTap: () => bridge.openAppSettings(),
            ),
          ],
        ),
        const SectionHeader(title: 'Device information'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              DeviceInformationRow(label: 'Manufacturer', value: d?.manufacturer ?? 'Unavailable'),
              DeviceInformationRow(label: 'Model', value: d?.model ?? 'Unavailable'),
              DeviceInformationRow(label: 'Android version', value: d == null ? 'Unavailable' : '${d.androidVersion} (API ${d.sdk})'),
              DeviceInformationRow(label: 'App version', value: d?.appVersion ?? 'Unavailable'),
              DeviceInformationRow(
                label: 'Motion detection',
                value: d == null ? 'Unknown' : (d.hasAccelerometer ? 'Supported' : 'Not supported'),
                valueColor: d != null && !d.hasAccelerometer ? AppColors.textSecondary : null,
              ),
              const DeviceInformationRow(label: 'Charger alert', value: 'Supported'),
              const DeviceInformationRow(label: 'Headphone alert', value: 'Supported'),
              DeviceInformationRow(
                label: 'SIM monitoring',
                value: d == null ? 'Unknown' : (d.hasTelephony ? 'Supported' : 'Not supported'),
                valueColor: d != null && !d.hasTelephony ? AppColors.textSecondary : null,
              ),
            ],
          ),
        ),
        const SectionHeader(title: 'About KEEPON'),
        SettingsGroup(
          children: [
            SettingsTile(icon: AppIcons.help, title: 'About the application', onTap: () => context.push('/info/about')),
            SettingsTile(icon: AppIcons.protection, title: 'Privacy policy', onTap: () => context.push('/info/privacy')),
            SettingsTile(icon: AppIcons.logs, title: 'Terms and conditions', onTap: () => context.push('/info/terms')),
            SettingsTile(icon: AppIcons.account, title: 'Support', onTap: () => context.push('/info/support')),
            SettingsTile(icon: AppIcons.link, title: 'Credits', onTap: () => context.push('/info/credits')),
          ],
        ),
      ],
    );
  }
}
