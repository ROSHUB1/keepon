import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utilities/snack.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/device_info_row.dart';
import '../../../core/widgets/screen_layout.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/settings_tile.dart';
import '../../../core/widgets/status_indicator.dart';
import '../../../shared/models/module_status.dart';
import '../../../shared/models/permission_state.dart';
import '../../../shared/models/protection_config.dart';
import '../../../shared/providers/protection_controller.dart';
import '../../../shared/providers/providers.dart';
import '../domain/module_info.dart';
import 'module_config_sheet.dart';
import 'preset_chips.dart';
import 'protection_module.dart';

class ProtectionScreen extends ConsumerWidget {
  const ProtectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(protectionProvider);
    final ctrl = ref.read(protectionProvider.notifier);
    final bridge = ref.read(bridgeProvider);
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;

    final failed = p.armed && p.error != null;
    final serviceText = failed
        ? 'Error'
        : p.armed
            ? (p.serviceRunning ? 'Running' : 'Not running')
            : 'Stopped';
    final serviceColor = failed
        ? AppColors.error
        : (p.armed && p.serviceRunning ? AppColors.success : null);

    final notif = p.permissions.notifications;
    final notifOk = notif == PermStatus.granted;
    final battery = p.permissions.batteryUnrestricted;

    bool toggleable(ModuleId id) {
      final s = p.statusOf(id);
      return s != ModuleStatus.unsupported && s != ModuleStatus.unavailable;
    }

    return ScreenList(
      children: [
        const ScreenHeader(title: 'Protection', subtitle: 'Choose what KEEPON watches for.'),
        RefreshBar(active: p.refreshing),
        const SizedBox(height: 8),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: [
                    Expanded(child: Text('Overall protection', style: text.titleSmall)),
                    StatusIndicator(status: p.overall),
                  ],
                ),
              ),
              const Divider(),
              DeviceInformationRow(
                label: 'Configured features',
                value: '${p.config.enabledCount} of ${ModuleId.values.length}',
              ),
              DeviceInformationRow(
                label: 'Active monitoring',
                value: '${p.activeModuleCount} of ${p.config.enabledCount} enabled',
              ),
              DeviceInformationRow(label: 'Monitoring service', value: serviceText, valueColor: serviceColor),
              DeviceInformationRow(
                label: 'Notifications',
                value: notifOk ? 'Allowed' : (notif == PermStatus.unknown ? 'Unknown' : 'Not allowed'),
                valueColor: notifOk ? AppColors.success : (notif == PermStatus.unknown ? null : AppColors.warning),
                actionLabel: (notif == PermStatus.denied || notif == PermStatus.permanentlyDenied) ? 'Allow' : null,
                onAction: () => notif == PermStatus.permanentlyDenied
                    ? bridge.openAppSettings()
                    : ctrl.requestPermission('notifications'),
              ),
              DeviceInformationRow(
                label: 'Battery restrictions',
                value: battery == null ? 'Unknown' : (battery ? 'Unrestricted' : 'May limit background work'),
                valueColor: battery == false ? AppColors.warning : null,
                actionLabel: battery == false ? 'Open settings' : null,
                onAction: () => bridge.openBatterySettings(),
              ),
              if (failed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Text(p.error!, style: text.bodySmall?.copyWith(color: AppColors.error)),
                ),
            ],
          ),
        ),
        const SectionHeader(title: 'Quick presets'),
        const PresetChips(),
        const SectionHeader(title: 'Modules'),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < ModuleId.values.length; i++) ...[
                if (i > 0) const Divider(),
                ProtectionModule(
                  info: moduleInfo(ModuleId.values[i]),
                  status: p.statusOf(ModuleId.values[i]),
                  enabled: p.config.module(ModuleId.values[i]).enabled,
                  toggleable: toggleable(ModuleId.values[i]),
                  onToggle: (v) async {
                    final err = await ctrl.setModule(
                      ModuleId.values[i],
                      p.config.module(ModuleId.values[i]).copyWith(enabled: v),
                    );
                    if (err != null && context.mounted) showKeepOnSnack(context, err);
                  },
                  onConfigure: () => showModuleConfigSheet(context, ModuleId.values[i]),
                ),
              ],
            ],
          ),
        ),
        const SectionHeader(title: 'Alarm'),
        SettingsGroup(
          children: [
            SettingsTile(
              icon: AppIcons.alerts,
              title: 'Alarm preferences',
              subtitle: 'Sound, volume, vibration and auto-stop',
              onTap: () => context.push('/settings'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'Ready means a module is set up. Active is only shown while the monitoring service is confirmed running.',
            style: text.bodySmall?.copyWith(color: t.textSecondary),
          ),
        ),
      ],
    );
  }
}
