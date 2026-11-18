import '../../../shared/models/protection_config.dart';

/// A one-tap selection of modules. Applying a preset never turns protection on by itself.
class ProtectionPreset {
  const ProtectionPreset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.modules,
  });

  final String id;
  final String title;
  final String subtitle;
  final Map<ModuleId, ModuleConfig> modules;

  bool matches(ProtectionConfiguration c) {
    for (final id in ModuleId.values) {
      final want = modules[id];
      final have = c.module(id);
      final wantOn = want?.enabled ?? false;
      if (have.enabled != wantOn) return false;
      if (wantOn && id == ModuleId.motion && have.sensitivity != want!.sensitivity) return false;
    }
    return true;
  }
}

const protectionPresets = <ProtectionPreset>[
  ProtectionPreset(
    id: 'table',
    title: 'On a table',
    subtitle: 'Alerts if someone picks the phone up.',
    modules: {ModuleId.motion: ModuleConfig(enabled: true, sensitivity: MotionSensitivity.high)},
  ),
  ProtectionPreset(
    id: 'charging',
    title: 'Charging',
    subtitle: 'Alerts if the charger is unplugged or the phone moves.',
    modules: {
      ModuleId.charger: ModuleConfig(enabled: true),
      ModuleId.motion: ModuleConfig(enabled: true, sensitivity: MotionSensitivity.medium),
    },
  ),
  ProtectionPreset(
    id: 'onthego',
    title: 'On the go',
    subtitle: 'Motion (low), headphones and SIM.',
    modules: {
      ModuleId.motion: ModuleConfig(enabled: true, sensitivity: MotionSensitivity.low),
      ModuleId.headphones: ModuleConfig(enabled: true),
      ModuleId.sim: ModuleConfig(enabled: true),
    },
  ),
  ProtectionPreset(
    id: 'everything',
    title: 'Everything',
    subtitle: 'Every module on.',
    modules: {
      ModuleId.motion: ModuleConfig(enabled: true, sensitivity: MotionSensitivity.medium),
      ModuleId.charger: ModuleConfig(enabled: true),
      ModuleId.headphones: ModuleConfig(enabled: true),
      ModuleId.sim: ModuleConfig(enabled: true),
      ModuleId.connectivity: ModuleConfig(enabled: true),
    },
  ),
];
