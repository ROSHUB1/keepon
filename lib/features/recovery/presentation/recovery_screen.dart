import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utilities/format.dart';
import '../../../core/utilities/snack.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/device_info_row.dart';
import '../../../core/widgets/screen_layout.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/settings_tile.dart';
import 'location_log_card.dart';
import '../../../shared/models/permission_state.dart';
import '../../../shared/providers/location_controller.dart';
import '../../../shared/providers/protection_controller.dart';
import '../../../shared/providers/providers.dart';

class RecoveryScreen extends ConsumerWidget {
  const RecoveryScreen({super.key});

  Future<void> _updateLocation(BuildContext context, WidgetRef ref) async {
    final bridge = ref.read(bridgeProvider);
    final perm = ref.read(protectionProvider).permissions.location;
    if (perm == PermStatus.permanentlyDenied) {
      final go = await showConfirmation(
        context,
        title: 'Location is blocked',
        message: 'Android is blocking location for KEEPON. Open the app settings to allow it.',
        confirmLabel: 'Open settings',
      );
      if (go) await bridge.openAppSettings();
      return;
    }
    if (perm != PermStatus.granted) {
      final ok = await showConfirmation(
        context,
        title: 'Allow location?',
        message:
            'KEEPON reads your phone\'s location only when you tap this button and saves it on this device so you can see where it was last known. It is not sent anywhere.',
        confirmLabel: 'Continue',
      );
      if (!ok || !context.mounted) return;
    }
    await ref.read(locationProvider.notifier).update();
    final msg = ref.read(locationProvider).message;
    if (msg != null && context.mounted) showKeepOnSnack(context, msg);
  }

  void _showInstructions(BuildContext context) {
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    const steps = [
      'Stay safe. Do not confront anyone or try to take the phone back yourself.',
      'On another device, open Google Find Hub (google.com/android/find) and sign in with the Google account used on this phone.',
      'If the phone may be nearby, use "Play sound". If it may be stolen, use "Secure device" to lock it and show a contact message.',
      'Contact your mobile carrier to suspend the SIM, and change passwords for important accounts.',
      'Report the loss to local authorities. Keep your device model and IMEI (on the box or in your carrier account) ready.',
      'Erase the device only as a last resort. Erasing removes your data but also stops Find Hub from locating it.',
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.88),
        decoration: BoxDecoration(
          color: t.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('If your phone is missing', style: text.titleLarge),
                const SizedBox(height: 14),
                for (var i = 0; i < steps.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: t.primarySoft, borderRadius: BorderRadius.circular(6)),
                          child: Text('${i + 1}', style: text.labelMedium?.copyWith(color: t.primary)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(steps[i], style: text.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(protectionProvider);
    final loc = ref.watch(locationProvider);
    final bridge = ref.read(bridgeProvider);
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    final d = p.device;
    final r = loc.record;

    final (permLabel, permColor) = switch (p.permissions.location) {
      PermStatus.granted => ('Allowed', AppColors.success),
      PermStatus.denied => ('Not allowed', AppColors.warning),
      PermStatus.permanentlyDenied => ('Blocked', AppColors.error),
      PermStatus.unknown => ('Unknown', null),
    };

    return ScreenList(
      children: [
        const ScreenHeader(
          title: 'Recovery',
          subtitle: 'Information that helps if your phone goes missing.',
        ),
        RefreshBar(active: p.refreshing || loc.busy),
        const SectionHeader(title: 'Last available location'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              DeviceInformationRow(
                label: 'Availability',
                value: r == null ? 'No location saved' : 'Saved on this device',
                valueColor: r == null ? null : AppColors.success,
              ),
              if (r == null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    'KEEPON has not recorded a location yet. Tap "Update location" to save where this phone is right now. Nothing is shown until Android provides a real location.',
                    style: text.bodySmall,
                  ),
                )
              else ...[
                const Divider(),
                DeviceInformationRow(
                  label: 'Coordinates',
                  value: '${r.latitude.toStringAsFixed(5)}, ${r.longitude.toStringAsFixed(5)}',
                ),
                const Divider(),
                DeviceInformationRow(
                  label: 'Recorded',
                  value: '${formatDateTimeFull(r.timestamp)} (${timeAgo(r.timestamp)})',
                ),
                const Divider(),
                DeviceInformationRow(
                  label: 'Accuracy',
                  value: r.accuracyMeters == null ? 'Not reported' : '±${r.accuracyMeters!.round()} m',
                ),
                const Divider(),
                DeviceInformationRow(label: 'Source', value: r.provider),
              ],
              const Divider(),
              DeviceInformationRow(label: 'Location permission', value: permLabel, valueColor: permColor),
            ],
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          label: 'Update location',
          icon: AppIcons.scan,
          loading: loc.busy,
          onPressed: () => _updateLocation(context, ref),
        ),
        if (loc.message != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
            child: Text(loc.message!, style: text.bodySmall?.copyWith(color: AppColors.warning)),
          ),
        const SectionHeader(title: 'Location log'),
        const LocationLogCard(),
        const SectionHeader(title: 'Recovery actions'),
        SettingsGroup(
          children: [
            SettingsTile(
              icon: AppIcons.scan,
              title: 'Open Google Find Hub',
              subtitle: 'Locate, ring or secure this phone from another device',
              onTap: () => bridge.openFindHub(),
            ),
            SettingsTile(
              icon: AppIcons.live,
              title: 'View last location in Maps',
              subtitle: r == null ? 'Available after a location is saved' : 'Opens your maps app',
              onTap: r == null ? null : () => bridge.openMap(r.latitude, r.longitude),
            ),
            SettingsTile(
              icon: AppIcons.protection,
              title: 'Lock the phone remotely',
              subtitle: 'Opens android.com/lock on this device. Open it on another device to lock this phone. Works if Remote Lock was set up in Android settings; KEEPON cannot lock the phone itself.',
              onTap: () => bridge.openUrl('https://android.com/lock'),
            ),
            SettingsTile(
              icon: AppIcons.help,
              title: 'Android theft protection settings',
              subtitle: 'Settings > Security & privacy > Device unlock > Theft protection',
              onTap: () => bridge.openSecuritySettings(),
            ),
            SettingsTile(
              icon: AppIcons.logs,
              title: 'Recovery instructions',
              subtitle: 'What to do, in a safe order',
              onTap: () => _showInstructions(context),
            ),
            SettingsTile(
              icon: AppIcons.link,
              title: 'Copy device details',
              subtitle: d == null ? 'Device details are unavailable' : 'Model and Android version, to share with your carrier',
              onTap: d == null
                  ? null
                  : () async {
                      await Clipboard.setData(ClipboardData(
                        text: 'Device: ${d.displayName}\nManufacturer: ${d.manufacturer}\nAndroid: ${d.androidVersion}',
                      ));
                      if (context.mounted) showKeepOnSnack(context, 'Device details copied.');
                    },
            ),
          ],
        ),
        const SectionHeader(title: 'This device'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              DeviceInformationRow(label: 'Model', value: d?.displayName ?? 'Unavailable'),
              const Divider(),
              DeviceInformationRow(label: 'Manufacturer', value: d?.manufacturer ?? 'Unavailable'),
              const Divider(),
              DeviceInformationRow(
                label: 'Android version',
                value: d == null ? 'Unavailable' : '${d.androidVersion} (API ${d.sdk})',
              ),
              const Divider(),
              DeviceInformationRow(label: 'App version', value: d?.appVersion ?? 'Unavailable'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'Remote recovery needs the phone to be on and connected. Location needs permission and supported services. A normal app cannot guarantee tracking, and KEEPON cannot guarantee that a stolen phone is recovered.',
            style: text.bodySmall?.copyWith(color: t.textSecondary),
          ),
        ),
      ],
    );
  }
}
