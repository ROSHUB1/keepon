import 'dart:convert';

import 'package:flutter/services.dart';

import '../../shared/models/device_information.dart';
import '../../shared/models/location_record.dart';
import '../../shared/models/permission_state.dart';
import '../../shared/models/protection_config.dart';

/// Result of asking Android to confirm the device PIN/pattern/fingerprint.
enum AuthResult { success, failed, unavailable }

class NativeFailure implements Exception {
  const NativeFailure(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Thin wrapper over the Kotlin side (MainActivity + ProtectionService).
class NativeBridge {
  static const MethodChannel _method = MethodChannel('keepon/native');
  static const EventChannel _events = EventChannel('keepon/events');

  /// Fires when the native side recorded something new (event, alarm change).
  Stream<void> get changes => _events.receiveBroadcastStream().map((_) {}).handleError((_) {});

  Future<T?> _try<T>(Future<T?> Function() f) async {
    try {
      return await f();
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  Future<DeviceInformation?> deviceInfo() async {
    final m = await _try(() => _method.invokeMapMethod<dynamic, dynamic>('getDeviceInfo'));
    return m == null ? null : DeviceInformation.fromMap(m);
  }

  Future<bool> isServiceRunning() async =>
      (await _try(() => _method.invokeMethod<bool>('isServiceRunning'))) ?? false;

  Future<bool> isAlarmRinging() async =>
      (await _try(() => _method.invokeMethod<bool>('isAlarmRinging'))) ?? false;

  /// Starts (or reconfigures) the foreground monitoring service. Throws [NativeFailure].
  Future<void> startService(String configJson) async {
    try {
      await _method.invokeMethod('startService', {'config': configJson});
    } on PlatformException catch (e) {
      throw NativeFailure(e.message ?? e.code);
    } on MissingPluginException {
      throw const NativeFailure('Android integration is not available on this platform.');
    }
  }

  Future<void> stopService() async {
    await _try(() => _method.invokeMethod<void>('stopService'));
  }

  Future<void> stopAlarm() async {
    await _try(() => _method.invokeMethod<void>('stopAlarm'));
  }

  /// Plays the alarm for a few seconds. Returns an error message, or null on success.
  Future<String?> testAlarm(AlarmConfiguration c) async {
    try {
      return await _method.invokeMethod<String>('testAlarm', {
        'sound': c.sound.name,
        'volume': c.volume,
        'vibrate': c.vibrate,
      });
    } on PlatformException catch (e) {
      return e.message ?? e.code;
    } on MissingPluginException {
      return 'Alarm playback is not available on this platform.';
    }
  }

  Future<PermStatus> permissionStatus(String name) async => PermStatus.parse(
      await _try(() => _method.invokeMethod<String>('permissionStatus', {'name': name})));

  Future<PermStatus> requestPermission(String name) async => PermStatus.parse(
      await _try(() => _method.invokeMethod<String>('requestPermission', {'name': name})));

  Future<PermissionState> readPermissions() async {
    final n = await permissionStatus('notifications');
    final l = await permissionStatus('location');
    final b = await _try(() => _method.invokeMethod<bool>('isIgnoringBatteryOptimizations'));
    final f = await _try(() => _method.invokeMethod<bool>('canUseFullScreenIntent'));
    final bg = await permissionStatus('backgroundLocation');
    return PermissionState(
      notifications: n,
      location: l,
      batteryUnrestricted: b,
      fullScreenAlarm: f,
      backgroundLocation: bg,
    );
  }

  /// Gets the best available location. Throws [NativeFailure] with a user-facing reason.
  Future<LocationRecord> getLocation() async {
    try {
      final m = await _method.invokeMapMethod<dynamic, dynamic>('getLocation');
      final r = m == null ? null : LocationRecord.tryParse(m);
      if (r == null) throw const NativeFailure('Android did not return a usable location.');
      return r;
    } on PlatformException catch (e) {
      throw NativeFailure(e.message ?? e.code);
    } on MissingPluginException {
      throw const NativeFailure('Location is not available on this platform.');
    }
  }

  Future<void> openAppSettings() async =>
      _try(() => _method.invokeMethod<void>('openAppSettings'));

  Future<void> openBatterySettings() async =>
      _try(() => _method.invokeMethod<void>('openBatterySettings'));

  /// Asks Android to confirm the device credential. [AuthResult.unavailable] means no screen lock is set.
  Future<AuthResult> authenticate({required String title, required String description}) async {
    try {
      final r = await _method.invokeMethod<String>('authenticate', {'title': title, 'description': description});
      return switch (r) {
        'success' => AuthResult.success,
        'unavailable' => AuthResult.unavailable,
        _ => AuthResult.failed,
      };
    } on MissingPluginException {
      return AuthResult.unavailable;
    } on PlatformException {
      return AuthResult.failed;
    }
  }

  /// Runs the full alarm path as a drill. Returns an error message, or null on success.
  Future<String?> simulateTrigger() async {
    try {
      await _method.invokeMethod('simulateTrigger');
      return null;
    } on PlatformException catch (e) {
      return e.message ?? e.code;
    } on MissingPluginException {
      return 'The test is not available on this platform.';
    }
  }

  Future<bool?> isDeviceSecure() => _try(() => _method.invokeMethod<bool>('isDeviceSecure'));

  Future<void> openUrl(String url) async => _try(() => _method.invokeMethod<void>('openUrl', {'url': url}));

  Future<void> openSecuritySettings() async =>
      _try(() => _method.invokeMethod<void>('openSecuritySettings'));

  /// Whether an alarm session is saved (it survives restarts until the owner stops it).
  Future<bool> isSessionActive() async {
    final m = await _try(() => _method.invokeMapMethod<dynamic, dynamic>('getSession'));
    return m != null && m['active'] == true;
  }

  Future<bool> isAdminActive() async =>
      (await _try(() => _method.invokeMethod<bool>('isAdminActive'))) ?? false;

  /// Opens Android's device admin screen for KEEPON. Returns false if it could not be opened.
  Future<bool> requestAdmin() async =>
      (await _try(() => _method.invokeMethod<bool>('requestAdmin'))) ?? false;

  Future<void> removeAdmin() async => _try(() => _method.invokeMethod<void>('removeAdmin'));

  Future<List<LocationLogEntry>> locationLog() async {
    final raw = await _try(() => _method.invokeMethod<String>('getLocationLog'));
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      final out = <LocationLogEntry>[];
      for (final e in list) {
        if (e is Map) {
          final entry = LocationLogEntry.tryParse(e);
          if (entry != null) out.add(entry);
        }
      }
      return out.reversed.toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> clearLocationLog() async =>
      _try(() => _method.invokeMethod<void>('clearLocationLog'));

  Future<void> openFullScreenSettings() async =>
      _try(() => _method.invokeMethod<void>('openFullScreenSettings'));

  Future<void> openFindHub() async => _try(() => _method.invokeMethod<void>('openFindHub'));

  Future<void> openMap(double lat, double lng) async =>
      _try(() => _method.invokeMethod<void>('openMap', {'lat': lat, 'lng': lng}));

  Future<List<Map<String, dynamic>>> peekEvents() async {
    final raw = await _try(() => _method.invokeMethod<String>('peekEvents'));
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return [];
      return [
        for (final e in list)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    } catch (_) {
      return [];
    }
  }

  Future<void> ackEvents(List<String> ids) async {
    if (ids.isEmpty) return;
    await _try(() => _method.invokeMethod<void>('ackEvents', {'ids': ids}));
  }
}
