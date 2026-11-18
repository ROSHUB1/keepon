import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/storage_service.dart';
import '../../integrations/android/native_bridge.dart';
import '../models/app_settings.dart';
import '../models/security_event.dart';

final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden in main()'),
);

final storageProvider = Provider<StorageService>((ref) => StorageService(ref.read(sharedPrefsProvider)));

final bridgeProvider = Provider<NativeBridge>((ref) => NativeBridge());

/// Set when a local save fails, so the UI can say so instead of failing silently.
final storageErrorProvider = StateProvider<String?>((ref) => null);

final activityFilterProvider = StateProvider<ActivityFilter>((ref) => ActivityFilter.all);

class SettingsController extends Notifier<ApplicationSettings> {
  @override
  ApplicationSettings build() => ref.read(storageProvider).loadSettings();

  Future<void> update(ApplicationSettings s) async {
    state = s;
    final ok = await ref.read(storageProvider).saveSettings(s);
    if (!ok) ref.read(storageErrorProvider.notifier).state = 'Settings could not be saved on this device.';
  }
}

final settingsProvider = NotifierProvider<SettingsController, ApplicationSettings>(SettingsController.new);

class EventsController extends Notifier<List<SecurityEvent>> {
  @override
  List<SecurityEvent> build() => ref.read(storageProvider).loadEvents();

  Future<void> record(
    EventType type, {
    required String description,
    EventSeverity severity = EventSeverity.info,
    String detection = '',
    bool alarm = false,
    String status = '',
  }) async {
    final now = DateTime.now();
    await _insert([
      SecurityEvent(
        id: '${now.microsecondsSinceEpoch}-${type.name}',
        type: type,
        timestamp: now,
        severity: severity,
        description: description,
        detection: detection,
        alarmTriggered: alarm,
        status: status,
      ),
    ]);
  }

  Future<void> _insert(List<SecurityEvent> items) async {
    final byId = {for (final e in state) e.id: e};
    for (final e in items) {
      byId[e.id] = e;
    }
    final list = byId.values.toList()..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = list.length > StorageService.maxEvents ? list.sublist(0, StorageService.maxEvents) : list;
    final ok = await ref.read(storageProvider).saveEvents(state);
    if (!ok) ref.read(storageErrorProvider.notifier).state = 'Activity history could not be saved on this device.';
  }

  /// Pulls events recorded by the native service (also while the app was closed).
  Future<void> syncNative() async {
    final bridge = ref.read(bridgeProvider);
    final raw = await bridge.peekEvents();
    if (raw.isEmpty) return;
    final parsed = <SecurityEvent>[];
    final ids = <String>[];
    for (final m in raw) {
      final e = SecurityEvent.tryParse(m);
      if (e != null) parsed.add(e);
      final id = m['id'];
      if (id is String) ids.add(id);
    }
    await _insert(parsed);
    await bridge.ackEvents(ids);
  }

  Future<void> clear() async {
    state = [];
    final ok = await ref.read(storageProvider).saveEvents(const []);
    if (!ok) ref.read(storageErrorProvider.notifier).state = 'Activity history could not be cleared.';
  }
}

final eventsProvider = NotifierProvider<EventsController, List<SecurityEvent>>(EventsController.new);
