import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/protection/domain/module_info.dart';
import '../../features/protection/domain/presets.dart';
import '../../integrations/android/native_bridge.dart';
import '../models/device_information.dart';
import '../models/module_status.dart';
import '../models/permission_state.dart';
import '../models/protection_config.dart';
import '../models/security_event.dart';
import 'providers.dart';

class ProtectionState {
  const ProtectionState({
    required this.config,
    this.serviceRunning = false,
    this.permissions = const PermissionState(),
    this.device,
    this.alarmRinging = false,
    this.error,
    this.busy = false,
    this.checked = false,
    this.refreshing = false,
    this.armingUntil,
    this.deviceSecure,
    this.sessionActive = false,
    this.adminActive = false,
  });

  final ProtectionConfiguration config;
  final bool serviceRunning;
  final PermissionState permissions;
  final DeviceInformation? device;
  final bool alarmRinging;
  final String? error;
  final bool busy;

  /// true once Android has been asked at least once.
  final bool checked;

  /// true while the service/permissions are being re-checked.
  final bool refreshing;

  /// While set (and in the future), motion detection is still in its 10 second arming delay.
  final DateTime? armingUntil;

  /// true when the phone has a PIN/pattern/password/fingerprint lock. null = unknown.
  final bool? deviceSecure;

  /// An alarm/protection session is saved and has not been stopped by the owner.
  final bool sessionActive;

  /// KEEPON has device admin rights (needed to lock the phone when an alarm triggers).
  final bool adminActive;

  bool get armed => config.armed;

  bool moduleSupported(ModuleId id) {
    final d = device;
    if (d == null) return true;
    return switch (id) {
      ModuleId.motion => d.hasAccelerometer,
      ModuleId.sim => d.hasTelephony,
      _ => true,
    };
  }

  ModuleStatus statusOf(ModuleId id) {
    if (!moduleSupported(id)) return ModuleStatus.unsupported;
    if (checked && device == null) return ModuleStatus.unavailable;
    if (!config.module(id).enabled) return ModuleStatus.off;
    if (config.armed && error != null) return ModuleStatus.error;
    if (config.armed && serviceRunning) return ModuleStatus.active;
    final n = permissions.notifications;
    if (n == PermStatus.denied || n == PermStatus.permanentlyDenied) {
      return ModuleStatus.permissionRequired;
    }
    return ModuleStatus.ready;
  }

  int get activeModuleCount =>
      ModuleId.values.where((m) => statusOf(m) == ModuleStatus.active).length;

  ModuleStatus get overall {
    if (config.armed && error != null) return ModuleStatus.error;
    if (config.armed && serviceRunning && config.enabledCount > 0) return ModuleStatus.active;
    if (config.enabledCount > 0) return ModuleStatus.ready;
    return ModuleStatus.off;
  }

  ProtectionState copyWith({
    ProtectionConfiguration? config,
    bool? serviceRunning,
    PermissionState? permissions,
    DeviceInformation? device,
    bool? alarmRinging,
    String? error,
    bool clearError = false,
    bool? busy,
    bool? checked,
    bool? refreshing,
    DateTime? armingUntil,
    bool clearArming = false,
    bool? deviceSecure,
    bool? sessionActive,
    bool? adminActive,
  }) =>
      ProtectionState(
        config: config ?? this.config,
        serviceRunning: serviceRunning ?? this.serviceRunning,
        permissions: permissions ?? this.permissions,
        device: device ?? this.device,
        alarmRinging: alarmRinging ?? this.alarmRinging,
        error: clearError ? null : (error ?? this.error),
        busy: busy ?? this.busy,
        checked: checked ?? this.checked,
        refreshing: refreshing ?? this.refreshing,
        armingUntil: clearArming ? null : (armingUntil ?? this.armingUntil),
        deviceSecure: deviceSecure ?? this.deviceSecure,
        sessionActive: sessionActive ?? this.sessionActive,
        adminActive: adminActive ?? this.adminActive,
      );
}

class ProtectionController extends Notifier<ProtectionState> {
  NativeBridge get _bridge => ref.read(bridgeProvider);
  EventsController get _events => ref.read(eventsProvider.notifier);

  @override
  ProtectionState build() {
    final cfg = ref.read(storageProvider).loadConfig();
    Future.microtask(refresh);
    return ProtectionState(config: cfg);
  }

  Future<void> _saveConfig(ProtectionConfiguration c) async {
    state = state.copyWith(config: c);
    final ok = await ref.read(storageProvider).saveConfig(c);
    if (!ok) ref.read(storageErrorProvider.notifier).state = 'Protection settings could not be saved on this device.';
  }

  /// Re-checks everything with Android: service, permissions, alarm, pending native events.
  Future<void> refresh() async {
    state = state.copyWith(refreshing: true);
    final device = await _bridge.deviceInfo();
    final running = await _bridge.isServiceRunning();
    final perms = await _bridge.readPermissions();
    final ringing = await _bridge.isAlarmRinging();
    final secure = await _bridge.isDeviceSecure();
    final session = await _bridge.isSessionActive();
    final admin = await _bridge.isAdminActive();
    await _events.syncNative();
    state = state.copyWith(
      device: device,
      serviceRunning: running,
      permissions: perms,
      alarmRinging: ringing,
      checked: true,
      refreshing: false,
      deviceSecure: secure,
      sessionActive: session,
      adminActive: admin,
    );
    if (state.busy) return;
    if (state.config.armed && !running) {
      await _recover();
    } else if (!state.config.armed && running) {
      await _bridge.stopService();
      state = state.copyWith(serviceRunning: false);
    }
  }

  Future<void> refreshPermissions() async {
    final perms = await _bridge.readPermissions();
    state = state.copyWith(permissions: perms);
  }

  Future<void> _recover() async {
    final alreadyFailed = state.error != null;
    if (!alreadyFailed) {
      await _events.record(
        EventType.serviceInterrupted,
        severity: EventSeverity.attention,
        description: 'The monitoring service was not running while protection was on.',
        detection: 'Checked when KEEPON was opened; KEEPON tried to restart it.',
      );
    }
    final err = await _startService(state.config);
    state = err == null ? state.copyWith(clearError: true) : state.copyWith(error: err);
  }

  Future<bool> _waitRunning(bool wanted) async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (await _bridge.isServiceRunning() == wanted) return true;
    }
    return false;
  }

  /// Starts or reconfigures the service. Returns an error message or null.
  Future<String?> _startService(ProtectionConfiguration cfg) async {
    try {
      final json = jsonEncode(cfg.toNativeJson(ref.read(settingsProvider)));
      await _bridge.startService(json);
    } on NativeFailure catch (e) {
      return e.message;
    }
    final ok = await _waitRunning(true);
    if (!ok) {
      return 'The monitoring service did not start. Android may be restricting KEEPON in the background.';
    }
    state = state.copyWith(serviceRunning: true);
    if (cfg.module(ModuleId.motion).enabled) {
      state = state.copyWith(armingUntil: DateTime.now().add(const Duration(seconds: 10)));
    }
    return null;
  }

  /// Confirms the device PIN/pattern/fingerprint when the user asked for it in Settings.
  /// Returns true when it is OK to continue (also when the phone has no screen lock).
  Future<bool> authorize(String reason, {bool force = false}) async {
    // An active alarm session always needs the unlock check (when the phone has a screen lock).
    if (!force && !state.sessionActive && !ref.read(settingsProvider).requireAuth) return true;
    final r = await _bridge.authenticate(title: 'Confirm it is you', description: reason);
    return r != AuthResult.failed;
  }

  Future<String?> setArmed(bool on, {bool skipAuth = false}) async {
    if (state.busy) return null;
    if (!on && !skipAuth) {
      final ok = await authorize('Unlock to turn off KEEPON protection.');
      if (!ok) return 'Unlock was not confirmed. Protection stays on.';
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      return on ? await _arm() : await _disarm('Protection was turned off.');
    } finally {
      state = state.copyWith(busy: false);
    }
  }

  Future<String?> _arm() async {
    final cfg = state.config.copyWith(armed: true);
    if (cfg.enabledCount == 0) return 'Turn on at least one protection module first.';

    var perms = await _bridge.readPermissions();
    if (perms.notifications != PermStatus.granted) {
      final status = await _bridge.requestPermission('notifications');
      perms = await _bridge.readPermissions();
      if (status != PermStatus.granted) {
        await _events.record(
          EventType.permissionUnavailable,
          severity: EventSeverity.attention,
          description: 'Notifications are off, so alerts and the alarm Stop button may not be visible.',
          detection: 'Notification permission: ${status.name}',
        );
      }
    }
    state = state.copyWith(permissions: perms);

    final err = await _startService(cfg);
    if (err != null) {
      await _events.record(
        EventType.serviceInterrupted,
        severity: EventSeverity.attention,
        description: 'Protection could not be started.',
        detection: err,
      );
      return err;
    }
    await _saveConfig(cfg);
    final names = cfg.enabledModules.map((m) => moduleInfo(m).title).join(', ');
    await _events.record(
      EventType.protectionActivated,
      description: 'Protection was turned on for: $names.',
      detection: 'Monitoring service confirmed running.',
    );
    return null;
  }

  Future<String?> _disarm(String reason) async {
    await _bridge.stopService();
    await _waitRunning(false);
    await _bridge.stopAlarm();
    await _saveConfig(state.config.copyWith(armed: false));
    state = state.copyWith(serviceRunning: false, alarmRinging: false, clearError: true, clearArming: true);
    await _events.record(
      EventType.protectionDeactivated,
      description: reason,
      detection: 'Monitoring service stopped.',
    );
    return null;
  }

  Future<String?> setModule(ModuleId id, ModuleConfig m) async {
    final before = state.config.module(id);
    if (state.config.armed && before.enabled && !m.enabled) {
      final ok = await authorize('Unlock to turn off this protection module.');
      if (!ok) return 'Unlock was not confirmed. The module stays on.';
    }
    final cfg = state.config.withModule(id, m);
    await _saveConfig(cfg);
    if (!cfg.armed) return null;
    if (cfg.enabledCount == 0) {
      await _disarm('Protection was turned off because no modules are enabled.');
    } else {
      final err = await _startService(cfg);
      state = err == null ? state.copyWith(clearError: true) : state.copyWith(error: err);
    }
    return null;
  }

  /// Applies a preset (modules only). Turning modules off while armed needs the unlock check.
  Future<String?> applyPreset(ProtectionPreset preset) async {
    final current = state.config;
    final disabling = current.armed &&
        ModuleId.values.any((id) => current.module(id).enabled && !(preset.modules[id]?.enabled ?? false));
    if (disabling) {
      final ok = await authorize('Unlock to change what KEEPON protects.');
      if (!ok) return 'Unlock was not confirmed. Nothing was changed.';
    }
    var cfg = current;
    for (final id in ModuleId.values) {
      final want = preset.modules[id];
      final prev = cfg.module(id);
      final on = (want?.enabled ?? false) && state.moduleSupported(id);
      cfg = cfg.withModule(id, prev.copyWith(enabled: on, sensitivity: want?.sensitivity ?? prev.sensitivity));
    }
    await _saveConfig(cfg);
    if (!cfg.armed) return null;
    if (cfg.enabledCount == 0) {
      await _disarm('Protection was turned off because no modules are enabled.');
    } else {
      final err = await _startService(cfg);
      state = err == null ? state.copyWith(clearError: true) : state.copyWith(error: err);
    }
    return null;
  }

  Future<void> setAlarm(AlarmConfiguration a) async {
    await _saveConfig(state.config.copyWith(alarm: a));
    await syncIfArmed();
  }

  /// Pushes the latest configuration to a running service.
  Future<void> syncIfArmed() async {
    if (!state.config.armed || !state.serviceRunning) return;
    final err = await _startService(state.config);
    state = err == null ? state.copyWith(clearError: true) : state.copyWith(error: err);
  }

  /// Stops the alarm after the unlock check. Returns false when unlock was not confirmed.
  Future<bool> stopAlarm() async {
    final ok = await authorize('Unlock to stop the alarm.', force: true);
    if (!ok) return false;
    await _bridge.stopAlarm();
    state = state.copyWith(alarmRinging: false);
    return true;
  }

  Future<String?> testAlarm() => _bridge.testAlarm(state.config.alarm);

  /// Turns "lock the phone when an alarm triggers" on or off. Turning it on opens Android's
  /// device admin screen if KEEPON is not an admin yet.
  Future<void> setLockOnAlarm(bool on) async {
    await setAlarm(state.config.alarm.copyWith(lockOnAlarm: on));
    if (on && !state.adminActive) await _bridge.requestAdmin();
  }

  /// The owner removes KEEPON's device admin (needed before uninstalling). Needs unlock.
  Future<bool> removeAdmin() async {
    final ok = await authorize('Unlock to remove KEEPON device admin.', force: true);
    if (!ok) return false;
    await _bridge.removeAdmin();
    state = state.copyWith(adminActive: false);
    await setAlarm(state.config.alarm.copyWith(lockOnAlarm: false));
    return true;
  }

  Future<PermStatus> requestPermission(String name) async {
    final s = await _bridge.requestPermission(name);
    await refreshPermissions();
    return s;
  }
}

final protectionProvider = NotifierProvider<ProtectionController, ProtectionState>(ProtectionController.new);
