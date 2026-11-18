class DeviceInformation {
  const DeviceInformation({
    required this.name,
    required this.manufacturer,
    required this.model,
    required this.androidVersion,
    required this.sdk,
    required this.appVersion,
    required this.hasAccelerometer,
    required this.hasTelephony,
  });

  final String name;
  final String manufacturer;
  final String model;
  final String androidVersion;
  final int sdk;
  final String appVersion;
  final bool hasAccelerometer;
  final bool hasTelephony;

  /// Model name without repeating the manufacturer ("TECNO BG6", not "TECNO TECNO BG6").
  String get displayName {
    if (manufacturer.isEmpty) return model;
    if (model.toLowerCase().startsWith(manufacturer.toLowerCase())) return model;
    return '$manufacturer $model';
  }

  factory DeviceInformation.fromMap(Map<dynamic, dynamic> m) => DeviceInformation(
        name: (m['device'] ?? m['model'] ?? '').toString(),
        manufacturer: (m['manufacturer'] ?? '').toString(),
        model: (m['model'] ?? '').toString(),
        androidVersion: (m['androidVersion'] ?? '').toString(),
        sdk: (m['sdk'] as num?)?.toInt() ?? 0,
        appVersion: (m['appVersion'] ?? '').toString(),
        hasAccelerometer: m['hasAccelerometer'] == true,
        hasTelephony: m['hasTelephony'] == true,
      );
}
