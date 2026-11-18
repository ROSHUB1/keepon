import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/models/app_settings.dart';
import '../../shared/models/location_record.dart';
import '../../shared/models/protection_config.dart';
import '../../shared/models/security_event.dart';

/// Local persistence (settings, protection configuration, event history, last location).
/// Saved preferences are NOT proof that monitoring is running; the service is verified separately.
class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static const maxEvents = 300;

  Map<String, dynamic>? _readMap(String key) {
    try {
      final raw = _prefs.getString(key);
      if (raw == null) return null;
      final v = jsonDecode(raw);
      return v is Map ? Map<String, dynamic>.from(v) : null;
    } catch (e) {
      debugPrint('KEEPON storage: could not read $key: $e');
      return null;
    }
  }

  ProtectionConfiguration loadConfig() {
    final m = _readMap('config');
    return m == null ? const ProtectionConfiguration() : ProtectionConfiguration.fromJson(m);
  }

  Future<bool> saveConfig(ProtectionConfiguration c) =>
      _prefs.setString('config', jsonEncode(c.toJson()));

  ApplicationSettings loadSettings() {
    final m = _readMap('settings');
    return m == null ? const ApplicationSettings() : ApplicationSettings.fromJson(m);
  }

  Future<bool> saveSettings(ApplicationSettings s) =>
      _prefs.setString('settings', jsonEncode(s.toJson()));

  List<SecurityEvent> loadEvents() {
    try {
      final raw = _prefs.getString('events');
      if (raw == null) return [];
      final list = jsonDecode(raw);
      if (list is! List) return [];
      final out = <SecurityEvent>[];
      for (final e in list) {
        if (e is Map) {
          final parsed = SecurityEvent.tryParse(e);
          if (parsed != null) out.add(parsed);
        }
      }
      return out;
    } catch (e) {
      debugPrint('KEEPON storage: could not read events: $e');
      return [];
    }
  }

  Future<bool> saveEvents(List<SecurityEvent> events) {
    final trimmed = events.length > maxEvents ? events.sublist(0, maxEvents) : events;
    return _prefs.setString('events', jsonEncode([for (final e in trimmed) e.toJson()]));
  }

  LocationRecord? loadLocation() {
    final m = _readMap('location');
    return m == null ? null : LocationRecord.tryParse(m);
  }

  Future<bool> saveLocation(LocationRecord r) =>
      _prefs.setString('location', jsonEncode(r.toJson()));
}
