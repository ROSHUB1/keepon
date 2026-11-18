import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utilities/snack.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/confirmation_dialog.dart';
import '../../../core/widgets/glyph_icon.dart';
import '../../../core/widgets/screen_layout.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/status_indicator.dart';
import '../../../shared/models/device_information.dart';
import '../../../shared/models/module_status.dart';
import '../../../shared/models/permission_state.dart';
import '../../../shared/models/protection_config.dart';
import '../../../shared/providers/protection_controller.dart';
import '../../../shared/providers/providers.dart';
import '../../activity/presentation/activity_timeline_item.dart';
import '../../protection/presentation/preset_chips.dart';
import 'arming_card.dart';
import 'setup_checklist.dart';
import '../../protection/domain/module_info.dart';
import '../../protection/presentation/module_visuals.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _toggle(BuildContext context, WidgetRef ref, ProtectionState p) async {
    final turningOn = !p.armed;
    final ok = await showConfirmation(
      context,
      title: turningOn ? 'Turn on protection?' : 'Turn off protection?',
      message: turningOn
          ? 'KEEPON will start a monitoring service with a persistent notification and watch the modules you enabled. Android may ask to allow notifications so you can see and stop alarms. For motion detection, you have 10 seconds to put the phone down.'
          : 'Your phone will no longer be watched for the modules you enabled.',
      confirmLabel: turningOn ? 'Turn on' : 'Turn off',
      destructive: !turningOn,
    );
    if (!ok || !context.mounted) return;
    final err = await ref.read(protectionProvider.notifier).setArmed(turningOn);
    if (err != null && context.mounted) showKeepOnSnack(context, err);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(protectionProvider);
    final events = ref.watch(eventsProvider);
    final storageError = ref.watch(storageErrorProvider);
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;

    final active = p.armed && p.serviceRunning && p.error == null;
    final attention = p.armed && !active;
    final stateColor = active ? AppColors.success : (attention ? AppColors.warning : t.textSecondary);

    final title = active
        ? 'Protection is on'
        : (attention ? 'Protection needs attention' : 'Protection is off');
    final body = active
        ? 'Your device is being monitored. Detected events are saved in Activity.'
        : attention
            ? (p.error ?? 'KEEPON is on, but the monitoring service is not running.')
            : (p.config.enabledCount == 0
                ? 'Your device is not currently being monitored. Choose what to protect in the Protection tab.'
                : 'Your device is not currently being monitored.');

    return ScreenList(
      children: [
        _Header(device: p.device, notifications: p.permissions.notifications),
        RefreshBar(active: p.refreshing),
        if (storageError != null) ...[
          const SizedBox(height: 8),
          _Banner(icon: Icons.error_outline_rounded, color: AppColors.warning, message: storageError),
        ],
        if (p.sessionActive && !p.alarmRinging) ...[
          const SizedBox(height: 8),
          const _Banner(
            icon: Icons.shield_outlined,
            color: AppColors.warning,
            message: 'An alarm session is active. Turning protection off needs your unlock.',
          ),
        ],
        if (p.alarmRinging) ...[
          const SizedBox(height: 8),
          _Banner(
            icon: Icons.notifications_active_rounded,
            color: AppColors.error,
            message: 'The alarm is ringing.',
            actionLabel: 'Stop alarm',
            onAction: () => context.push('/alarm'),
          ),
        ],
        if (p.armingUntil != null && p.armingUntil!.isAfter(DateTime.now())) ...[
          const SizedBox(height: 8),
          ArmingCard(
            key: ValueKey(p.armingUntil),
            until: p.armingUntil!,
            onCancel: () => ref.read(protectionProvider.notifier).setArmed(false, skipAuth: true),
          ),
        ],
        const SetupChecklist(),
        const SizedBox(height: 8),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(
                    size: 44,
                    color: stateColor,
                    child: GlyphIcon(AppIcons.protection, size: 24, color: stateColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.titleLarge),
                        const SizedBox(height: 2),
                        Text(body, style: text.bodyMedium?.copyWith(color: t.textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${p.serviceRunning ? 'Service running' : 'Service stopped'}  ·  ${p.config.enabledCount} of ${ModuleId.values.length} modules enabled',
                style: text.bodySmall,
              ),
              const SizedBox(height: 14),
              if (p.armed)
                SecondaryButton(
                  label: 'Turn off protection',
                  icon: Icons.power_settings_new_rounded,
                  danger: true,
                  onPressed: p.busy ? null : () => _toggle(context, ref, p),
                )
              else
                PrimaryButton(
                  label: 'Turn on protection',
                  icon: AppIcons.protection,
                  loading: p.busy,
                  onPressed: () => _toggle(context, ref, p),
                ),
            ],
          ),
        ),
        if (p.config.enabledCount == 0 && !p.armed) ...[
          const SectionHeader(title: 'Quick setup'),
          const PresetChips(),
        ],
        SectionHeader(
          title: 'Protection modules',
          actionLabel: 'Configure',
          onAction: () => context.go('/protection'),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < ModuleId.values.length; i++) ...[
                if (i > 0) const Divider(indent: 64),
                _ModuleRow(id: ModuleId.values[i], p: p, onTap: () => context.go('/protection')),
              ],
            ],
          ),
        ),
        SectionHeader(
          title: 'Recent activity',
          actionLabel: 'View all',
          onAction: () => context.go('/activity'),
        ),
        AppCard(
          padding: EdgeInsets.zero,
          child: events.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('No activity recorded yet.', style: text.titleSmall),
                      const SizedBox(height: 2),
                      Text('Detected security events will appear here.', style: text.bodySmall),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < events.length && i < 3; i++) ...[
                      if (i > 0) const Divider(indent: 64),
                      ActivityTimelineItem(
                        event: events[i],
                        onTap: () => context.push('/event/${events[i].id}'),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.device, required this.notifications});

  final DeviceInformation? device;
  final PermStatus notifications;

  @override
  Widget build(BuildContext context) {
    final t = KeepOnTokens.of(context);
    final text = Theme.of(context).textTheme;
    final notifOk = notifications == PermStatus.granted;
    return Row(
      children: [
        Image.asset('assets/brand/k_mark.png', height: 28, semanticLabel: 'KEEPON logo'),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KEEPON', style: text.titleMedium?.copyWith(letterSpacing: 1.2, fontWeight: FontWeight.w700)),
              Text(
                device == null ? 'Device information unavailable' : device!.displayName,
                style: text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: notifOk ? 'Notifications' : 'Notifications are off',
          onPressed: () => context.push('/settings'),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              GlyphIcon(AppIcons.alerts, size: 24, color: t.textPrimary),
              if (!notifOk)
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      shape: BoxShape.circle,
                      border: Border.all(color: t.background, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Settings',
          onPressed: () => context.push('/settings'),
          icon: GlyphIcon(AppIcons.settings, size: 24, color: t.textPrimary),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.message, this.actionLabel, this.onAction});

  final IconData icon;
  final Color color;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: color.withValues(alpha: 0.10),
      borderColor: color.withValues(alpha: 0.35),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Text(message, style: Theme.of(context).textTheme.titleSmall))),
          if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.id, required this.p, required this.onTap});

  final ModuleId id;
  final ProtectionState p;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = KeepOnTokens.of(context);
    final status = p.statusOf(id);
    final c = status == ModuleStatus.off ? t.textSecondary : status.color;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              IconBadge(color: c, child: GlyphIcon(moduleIcon(id), size: AppSize.iconInBadge, color: c)),
              const SizedBox(width: 12),
              Expanded(child: Text(moduleInfo(id).title, style: Theme.of(context).textTheme.titleSmall)),
              const SizedBox(width: 8),
              StatusIndicator(status: status),
            ],
          ),
        ),
      ),
    );
  }
}
