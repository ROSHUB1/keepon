enum PermStatus {
  granted,
  denied,
  permanentlyDenied,
  unknown;

  static PermStatus parse(Object? v) {
    for (final s in values) {
      if (s.name == v) return s;
    }
    return PermStatus.unknown;
  }
}

class PermissionState {
  const PermissionState({
    this.notifications = PermStatus.unknown,
    this.location = PermStatus.unknown,
    this.batteryUnrestricted,
    this.fullScreenAlarm,
    this.backgroundLocation = PermStatus.unknown,
  });

  final PermStatus notifications;
  final PermStatus location;

  /// true = Android is not optimizing KEEPON's battery use. null = unknown.
  final bool? batteryUnrestricted;

  /// true when Android lets KEEPON show the alarm over the lock screen.
  /// null = not applicable (older Android) or unknown.
  final bool? fullScreenAlarm;

  /// "Allow all the time" location, needed to keep recording location after a restart.
  final PermStatus backgroundLocation;
}
