import 'app_settings.dart';

enum ModuleId { motion, charger, headphones, sim, connectivity }

enum MotionSensitivity { low, medium, high }

/// siren = KEEPON's own electronic security siren; the others are Android's system sounds.
enum AlarmSound { siren, alarm, ringtone, notification }

class ModuleConfig {
  const ModuleConfig({
    this.enabled = false,
    this.alarmEnabled = true,
    this.sensitivity = MotionSensitivity.medium,
  });

  final bool enabled;
  final bool alarmEnabled;
  final MotionSensitivity sensitivity;

  ModuleConfig copyWith({bool? enabled, bool? alarmEnabled, MotionSensitivity? sensitivity}) =>
      ModuleConfig(
        enabled: enabled ?? this.enabled,
        alarmEnabled: alarmEnabled ?? this.alarmEnabled,
        sensitivity: sensitivity ?? this.sensitivity,
      );

  Map<String, dynamic> toJson() => {
        'enabled': enabled,
        'alarm': alarmEnabled,
        'sensitivity': sensitivity.name,
      };

  factory ModuleConfig.fromJson(Map<String, dynamic> j) => ModuleConfig(
        enabled: j['enabled'] as bool? ?? false,
        alarmEnabled: j['alarm'] as bool? ?? true,
        sensitivity: MotionSensitivity.values.firstWhere(
          (s) => s.name == j['sensitivity'],
          orElse: () => MotionSensitivity.medium,
        ),
      );
}

/// Alarm sound plus how KEEPON responds when a trigger is confirmed.
class AlarmConfiguration {
  const AlarmConfiguration({
    this.sound = AlarmSound.siren,
    this.volume = 70,
    this.vibrate = true,
    this.autoStopSeconds = 60,
    this.entryDelaySeconds = 5,
    this.ignoreWhileUnlocked = false,
    this.lockOnAlarm = false,
    this.trackLocation = true,
    this.tamperAlarm = false,
  });

  final AlarmSound sound;
  final int volume; // 10..100 percent of the phone's alarm volume
  final bool vibrate;
  final int autoStopSeconds; // 0 = until the owner stops it

  /// Seconds the owner has to unlock the phone before the alarm starts (0 = immediately).
  final int entryDelaySeconds;

  /// Ignore motion/charger/headphone events while the phone is unlocked and in use.
  final bool ignoreWhileUnlocked;

  /// Lock the screen when an alarm triggers (needs device admin).
  final bool lockOnAlarm;

  /// Record the phone's location on the device while an alarm session is active.
  final bool trackLocation;

  /// Sound the alarm (after the usual checks) when KEEPON finds its own service was stopped.
  /// Off by default: Android sometimes ends background processes, which would cause false alarms.
  final bool tamperAlarm;

  AlarmConfiguration copyWith({
    AlarmSound? sound,
    int? volume,
    bool? vibrate,
    int? autoStopSeconds,
    int? entryDelaySeconds,
    bool? ignoreWhileUnlocked,
    bool? lockOnAlarm,
    bool? trackLocation,
    bool? tamperAlarm,
  }) =>
      AlarmConfiguration(
        sound: sound ?? this.sound,
        volume: volume ?? this.volume,
        vibrate: vibrate ?? this.vibrate,
        autoStopSeconds: autoStopSeconds ?? this.autoStopSeconds,
        entryDelaySeconds: entryDelaySeconds ?? this.entryDelaySeconds,
        ignoreWhileUnlocked: ignoreWhileUnlocked ?? this.ignoreWhileUnlocked,
        lockOnAlarm: lockOnAlarm ?? this.lockOnAlarm,
        trackLocation: trackLocation ?? this.trackLocation,
        tamperAlarm: tamperAlarm ?? this.tamperAlarm,
      );

  Map<String, dynamic> toJson() => {
        'sound': sound.name,
        'volume': volume,
        'vibrate': vibrate,
        'autoStop': autoStopSeconds,
        'entryDelay': entryDelaySeconds,
        'ignoreOwnerPresent': ignoreWhileUnlocked,
        'lockOnAlarm': lockOnAlarm,
        'trackLocation': trackLocation,
        'tamperAlarm': tamperAlarm,
      };

  factory AlarmConfiguration.fromJson(Map<String, dynamic> j) => AlarmConfiguration(
        sound: AlarmSound.values.firstWhere(
          (s) => s.name == j['sound'],
          orElse: () => AlarmSound.siren,
        ),
        volume: (j['volume'] as num?)?.toInt().clamp(10, 100) ?? 70,
        vibrate: j['vibrate'] as bool? ?? true,
        autoStopSeconds: (j['autoStop'] as num?)?.toInt() ?? 60,
        entryDelaySeconds: (j['entryDelay'] as num?)?.toInt() ?? 5,
        ignoreWhileUnlocked: j['ignoreOwnerPresent'] as bool? ?? false,
        lockOnAlarm: j['lockOnAlarm'] as bool? ?? false,
        trackLocation: j['trackLocation'] as bool? ?? true,
        tamperAlarm: j['tamperAlarm'] as bool? ?? false,
      );
}

class ProtectionConfiguration {
  const ProtectionConfiguration({
    this.armed = false,
    this.modules = const {},
    this.alarm = const AlarmConfiguration(),
  });

  final bool armed;
  final Map<ModuleId, ModuleConfig> modules;
  final AlarmConfiguration alarm;

  ModuleConfig module(ModuleId id) => modules[id] ?? const ModuleConfig();

  List<ModuleId> get enabledModules =>
      ModuleId.values.where((m) => module(m).enabled).toList();

  int get enabledCount => enabledModules.length;

  ProtectionConfiguration copyWith({bool? armed, AlarmConfiguration? alarm}) =>
      ProtectionConfiguration(
        armed: armed ?? this.armed,
        modules: modules,
        alarm: alarm ?? this.alarm,
      );

  ProtectionConfiguration withModule(ModuleId id, ModuleConfig config) =>
      ProtectionConfiguration(
        armed: armed,
        modules: {...modules, id: config},
        alarm: alarm,
      );

  Map<String, dynamic> toJson() => {
        'armed': armed,
        'modules': {for (final e in modules.entries) e.key.name: e.value.toJson()},
        'alarm': alarm.toJson(),
      };

  factory ProtectionConfiguration.fromJson(Map<String, dynamic> j) {
    final mods = <ModuleId, ModuleConfig>{};
    final raw = j['modules'];
    if (raw is Map) {
      for (final id in ModuleId.values) {
        final v = raw[id.name];
        if (v is Map) mods[id] = ModuleConfig.fromJson(Map<String, dynamic>.from(v));
      }
    }
    final a = j['alarm'];
    return ProtectionConfiguration(
      armed: j['armed'] as bool? ?? false,
      modules: mods,
      alarm: a is Map
          ? AlarmConfiguration.fromJson(Map<String, dynamic>.from(a))
          : const AlarmConfiguration(),
    );
  }

  /// JSON understood by the native Android monitoring service.
  Map<String, dynamic> toNativeJson(ApplicationSettings settings) => {
        for (final id in ModuleId.values) id.name: module(id).toJson(),
        'alarm': alarm.toJson(),
        'notifySecurity': settings.notifySecurity,
        'notifyAlarm': settings.notifyAlarm,
        'requireAuth': settings.requireAuth,
      };
}
