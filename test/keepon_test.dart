import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keepon/core/theme/app_theme.dart';
import 'package:keepon/core/widgets/empty_state.dart';
import 'package:keepon/core/widgets/status_indicator.dart';
import 'package:keepon/features/protection/domain/presets.dart';
import 'package:keepon/shared/models/app_settings.dart';
import 'package:keepon/shared/models/device_information.dart';
import 'package:keepon/shared/models/module_status.dart';
import 'package:keepon/shared/models/permission_state.dart';
import 'package:keepon/shared/models/protection_config.dart';
import 'package:keepon/shared/models/security_event.dart';
import 'package:keepon/shared/providers/protection_controller.dart';

void main() {
  group('SecurityEvent', () {
    test('round trips through JSON', () {
      final e = SecurityEvent(
        id: 'a',
        type: EventType.motionDetected,
        timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        severity: EventSeverity.critical,
        description: 'moved',
        detection: 'x',
        alarmTriggered: true,
      );
      final back = SecurityEvent.tryParse(e.toJson())!;
      expect(back.type, EventType.motionDetected);
      expect(back.alarmTriggered, true);
      expect(back.timestamp, e.timestamp);
    });

    test('unknown types are skipped, not invented', () {
      expect(SecurityEvent.tryParse({'id': 'x', 'type': 'nope', 'ts': 1}), isNull);
    });

    test('filters match their categories', () {
      final alert = SecurityEvent(
          id: '1', type: EventType.chargerDisconnected, timestamp: DateTime(2026), severity: EventSeverity.critical, description: '');
      final prot = SecurityEvent(
          id: '2', type: EventType.protectionActivated, timestamp: DateTime(2026), severity: EventSeverity.info, description: '');
      expect(alert.matches(ActivityFilter.alerts), true);
      expect(alert.matches(ActivityFilter.deviceChanges), true);
      expect(prot.matches(ActivityFilter.protection), true);
      expect(prot.matches(ActivityFilter.alerts), false);
    });
  });

  group('ProtectionConfiguration', () {
    test('persists and restores module settings', () {
      final c = const ProtectionConfiguration()
          .withModule(ModuleId.motion, const ModuleConfig(enabled: true, sensitivity: MotionSensitivity.high))
          .copyWith(armed: true);
      final back = ProtectionConfiguration.fromJson(c.toJson());
      expect(back.armed, true);
      expect(back.module(ModuleId.motion).sensitivity, MotionSensitivity.high);
      expect(back.enabledCount, 1);
    });
  });

  group('Presets and settings', () {
    test('a preset matches only the modules it enables', () {
      final table = protectionPresets.firstWhere((p) => p.id == 'table');
      var c = const ProtectionConfiguration();
      expect(table.matches(c), false);
      c = c.withModule(ModuleId.motion, const ModuleConfig(enabled: true, sensitivity: MotionSensitivity.high));
      expect(table.matches(c), true);
      c = c.withModule(ModuleId.charger, const ModuleConfig(enabled: true));
      expect(table.matches(c), false);
    });

    test('settings keep unlock confirmation on by default and round trip', () {
      expect(const ApplicationSettings().requireAuth, true);
      final back = ApplicationSettings.fromJson(
        const ApplicationSettings(requireAuth: false, theftProtectionReviewed: true).toJson(),
      );
      expect(back.requireAuth, false);
      expect(back.theftProtectionReviewed, true);
    });

    test('onboarding is not done by default and is remembered', () {
      expect(const ApplicationSettings().onboardingDone, false);
      final back = ApplicationSettings.fromJson(const ApplicationSettings(onboardingDone: true).toJson());
      expect(back.onboardingDone, true);
    });

    test('native config carries the unlock setting', () {
      final json = const ProtectionConfiguration().toNativeJson(const ApplicationSettings());
      expect(json['requireAuth'], true);
    });
  });

  group('Anti-theft response', () {
    test('alarm defaults use the security siren with a short entry delay', () {
      const a = AlarmConfiguration();
      expect(a.sound, AlarmSound.siren);
      expect(a.entryDelaySeconds, 5);
      expect(a.ignoreWhileUnlocked, false);
      expect(a.lockOnAlarm, false);
      expect(a.trackLocation, true);
    });

    test('older saved alarm settings still load', () {
      final a = AlarmConfiguration.fromJson({'sound': 'alarm', 'volume': 80});
      expect(a.sound, AlarmSound.alarm);
      expect(a.entryDelaySeconds, 5);
      expect(AlarmConfiguration.fromJson({'sound': 'unknown'}).sound, AlarmSound.siren);
    });

    test('new detections exist and are filed correctly', () {
      expect(ModuleId.values.contains(ModuleId.connectivity), true);
      expect(EventType.parse('tamperDetected'), EventType.tamperDetected);
      expect(EventType.parse('pinFailed'), EventType.pinFailed);
      expect(EventType.parse('connectivityLost'), EventType.connectivityLost);
      final pin = SecurityEvent(
        id: 'p', type: EventType.pinFailed, timestamp: DateTime(2026),
        severity: EventSeverity.attention, description: 'x',
      );
      expect(pin.matches(ActivityFilter.alerts), true);
      final net = SecurityEvent(
        id: 'n', type: EventType.connectivityLost, timestamp: DateTime(2026),
        severity: EventSeverity.critical, description: 'x',
      );
      expect(net.matches(ActivityFilter.deviceChanges), true);
    });

    test('alarm on unexpected stop is off by default and reaches the service', () {
      expect(const AlarmConfiguration().tamperAlarm, false);
      final json = const ProtectionConfiguration()
          .copyWith(alarm: const AlarmConfiguration(tamperAlarm: true))
          .toNativeJson(const ApplicationSettings());
      expect((json['alarm'] as Map<String, dynamic>)['tamperAlarm'], true);
      expect(json.containsKey('connectivity'), true);
    });

    test('native config carries the response settings', () {
      final cfg = const ProtectionConfiguration()
          .copyWith(alarm: const AlarmConfiguration(entryDelaySeconds: 10, lockOnAlarm: true));
      final alarm = cfg.toNativeJson(const ApplicationSettings())['alarm'] as Map<String, dynamic>;
      expect(alarm['sound'], 'siren');
      expect(alarm['entryDelay'], 10);
      expect(alarm['lockOnAlarm'], true);
      expect(alarm['ignoreOwnerPresent'], false);
    });

    test('events keep their security status', () {
      final e = SecurityEvent(
        id: 's', type: EventType.alarmCancelled, timestamp: DateTime(2026),
        severity: EventSeverity.info, description: 'x', status: 'Cancelled by owner',
      );
      expect(SecurityEvent.tryParse(e.toJson())!.status, 'Cancelled by owner');
      expect(e.matches(ActivityFilter.protection), true);
    });

    test('an active session is reflected in the state', () {
      expect(const ProtectionState(config: ProtectionConfiguration()).sessionActive, false);
      expect(const ProtectionState(config: ProtectionConfiguration(), sessionActive: true).sessionActive, true);
    });
  });

  group('Module status', () {
    final cfg = const ProtectionConfiguration()
        .withModule(ModuleId.charger, const ModuleConfig(enabled: true));

    test('off when disabled', () {
      expect(ProtectionState(config: cfg).statusOf(ModuleId.headphones), ModuleStatus.off);
    });
    test('ready when enabled but not armed', () {
      expect(ProtectionState(config: cfg).statusOf(ModuleId.charger), ModuleStatus.ready);
    });
    test('a saved preference is not proof of monitoring', () {
      final s = ProtectionState(config: cfg.copyWith(armed: true), serviceRunning: false);
      expect(s.statusOf(ModuleId.charger), ModuleStatus.ready);
    });
    test('active only when the service is confirmed running', () {
      final s = ProtectionState(config: cfg.copyWith(armed: true), serviceRunning: true);
      expect(s.statusOf(ModuleId.charger), ModuleStatus.active);
    });
    test('error when a failure was recorded', () {
      final s = ProtectionState(config: cfg.copyWith(armed: true), error: 'failed');
      expect(s.statusOf(ModuleId.charger), ModuleStatus.error);
    });
    test('permission required when notifications are blocked', () {
      final s = ProtectionState(
        config: cfg,
        permissions: const PermissionState(notifications: PermStatus.denied),
      );
      expect(s.statusOf(ModuleId.charger), ModuleStatus.permissionRequired);
    });
    test('unsupported when the phone lacks the hardware', () {
      const device = DeviceInformation(
        name: 'x', manufacturer: 'A', model: 'B', androidVersion: '14', sdk: 34,
        appVersion: '1', hasAccelerometer: false, hasTelephony: true,
      );
      final c = const ProtectionConfiguration().withModule(ModuleId.motion, const ModuleConfig(enabled: true));
      expect(ProtectionState(config: c, device: device).statusOf(ModuleId.motion), ModuleStatus.unsupported);
    });
    test('unavailable when Android could not be reached', () {
      expect(ProtectionState(config: cfg, checked: true).statusOf(ModuleId.charger), ModuleStatus.unavailable);
    });
    test('device name does not repeat the manufacturer', () {
      const d = DeviceInformation(
        name: 'x', manufacturer: 'TECNO', model: 'TECNO BG6', androidVersion: '14', sdk: 34,
        appVersion: '1', hasAccelerometer: true, hasTelephony: true,
      );
      expect(d.displayName, 'TECNO BG6');
    });
    test('permission state defaults to unknown', () {
      expect(const PermissionState().notifications, PermStatus.unknown);
    });
  });

  group('Theme and widgets', () {
    testWidgets('light and dark themes switch', (tester) async {
      Future<void> pump(Brightness b) => tester.pumpWidget(MaterialApp(
            theme: buildKeepOnTheme(b),
            home: Builder(builder: (c) => Text(KeepOnTokens.of(c).isDark ? 'dark' : 'light')),
          ));
      await pump(Brightness.light);
      await tester.pumpAndSettle();
      expect(find.text('light'), findsOneWidget);
      await pump(Brightness.dark);
      await tester.pumpAndSettle();
      expect(find.text('dark'), findsOneWidget);
    });

    testWidgets('empty state shows its message', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildKeepOnTheme(Brightness.light),
        home: const Scaffold(
          body: EmptyState(icon: Icons.history_rounded, title: 'No activity recorded yet.', message: 'Detected security events will appear here.'),
        ),
      ));
      expect(find.text('No activity recorded yet.'), findsOneWidget);
    });

    testWidgets('status indicator shows the status label', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildKeepOnTheme(Brightness.light),
        home: const Scaffold(body: StatusIndicator(status: ModuleStatus.active)),
      ));
      expect(find.text('Active'), findsOneWidget);
    });
  });
}
