class LocationRecord {
  const LocationRecord({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracyMeters,
    this.provider = 'unknown',
  });

  final double latitude;
  final double longitude;
  final DateTime timestamp; // when the fix was taken, as reported by Android
  final double? accuracyMeters;
  final String provider;

  Map<String, dynamic> toJson() => {
        'lat': latitude,
        'lng': longitude,
        'time': timestamp.millisecondsSinceEpoch,
        'accuracy': accuracyMeters,
        'provider': provider,
      };

  static LocationRecord? tryParse(Map<dynamic, dynamic> m) {
    try {
      return LocationRecord(
        latitude: (m['lat'] as num).toDouble(),
        longitude: (m['lng'] as num).toDouble(),
        timestamp: DateTime.fromMillisecondsSinceEpoch((m['time'] as num).toInt()),
        accuracyMeters: (m['accuracy'] as num?)?.toDouble(),
        provider: (m['provider'] ?? 'unknown').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}

/// One entry of the encrypted on-device location log kept during an alarm session.
class LocationLogEntry {
  const LocationLogEntry({
    required this.latitude,
    required this.longitude,
    required this.fixTime,
    required this.recorded,
    required this.live,
    required this.online,
    this.accuracyMeters,
    this.provider = 'unknown',
  });

  final double latitude;
  final double longitude;
  final DateTime fixTime; // when Android took the fix
  final DateTime recorded; // when KEEPON saved it
  final bool live; // true = fresh fix, false = last-known fix reported by Android
  final bool online; // whether the phone had internet when it was recorded
  final double? accuracyMeters;
  final String provider;

  static LocationLogEntry? tryParse(Map<dynamic, dynamic> m) {
    try {
      return LocationLogEntry(
        latitude: (m['lat'] as num).toDouble(),
        longitude: (m['lng'] as num).toDouble(),
        fixTime: DateTime.fromMillisecondsSinceEpoch((m['time'] as num).toInt()),
        recorded: DateTime.fromMillisecondsSinceEpoch((m['recorded'] as num).toInt()),
        live: m['kind'] == 'live',
        online: m['online'] == true,
        accuracyMeters: (m['accuracy'] as num?)?.toDouble(),
        provider: (m['provider'] ?? 'unknown').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
