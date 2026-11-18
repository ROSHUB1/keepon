enum EventType {
  motionDetected('Motion detected'),
  chargerDisconnected('Charger disconnected'),
  headphonesDisconnected('Headphones disconnected'),
  simStateChanged('SIM state changed'),
  protectionActivated('Protection activated'),
  protectionDeactivated('Protection deactivated'),
  serviceInterrupted('Monitoring service interrupted'),
  permissionUnavailable('Permission unavailable'),
  alarmCancelled('Alarm cancelled'),
  alarmStopped('Alarm stopped'),
  connectivityLost('Network connection lost'),
  pinFailed('Wrong lock-screen code'),
  tamperDetected('Tamper detected');

  const EventType(this.title);
  final String title;

  static EventType? parse(Object? name) {
    for (final t in values) {
      if (t.name == name) return t;
    }
    return null;
  }
}

enum EventSeverity {
  info,
  attention,
  critical;

  static EventSeverity parse(Object? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return EventSeverity.info;
  }
}

enum ActivityFilter {
  all('All'),
  alerts('Security Alerts'),
  deviceChanges('Device Changes'),
  protection('Protection Activity');

  const ActivityFilter(this.label);
  final String label;
}

class SecurityEvent {
  const SecurityEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.severity,
    required this.description,
    this.detection = '',
    this.alarmTriggered = false,
    this.status = '',
  });

  final String id;
  final EventType type;
  final DateTime timestamp;
  final EventSeverity severity;
  final String description;
  final String detection;
  final bool alarmTriggered;

  /// Security status at that moment, e.g. "Alarm active" or "Cancelled by owner".
  final String status;

  bool matches(ActivityFilter f) {
    switch (f) {
      case ActivityFilter.all:
        return true;
      case ActivityFilter.alerts:
        return severity == EventSeverity.critical || type == EventType.pinFailed;
      case ActivityFilter.deviceChanges:
        return type == EventType.motionDetected ? false : _isDeviceChange;
      case ActivityFilter.protection:
        return type == EventType.protectionActivated ||
            type == EventType.protectionDeactivated ||
            type == EventType.serviceInterrupted ||
            type == EventType.alarmCancelled ||
            type == EventType.alarmStopped ||
            type == EventType.tamperDetected ||
            type == EventType.permissionUnavailable;
    }
  }

  bool get _isDeviceChange =>
      type == EventType.chargerDisconnected ||
      type == EventType.headphonesDisconnected ||
      type == EventType.connectivityLost ||
      type == EventType.simStateChanged;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'ts': timestamp.millisecondsSinceEpoch,
        'severity': severity.name,
        'description': description,
        'detection': detection,
        'alarm': alarmTriggered,
        'status': status,
      };

  static SecurityEvent? tryParse(Map<dynamic, dynamic> m) {
    try {
      final type = EventType.parse(m['type']);
      final id = m['id'];
      final ts = m['ts'];
      if (type == null || id is! String || ts is! num) return null;
      return SecurityEvent(
        id: id,
        type: type,
        timestamp: DateTime.fromMillisecondsSinceEpoch(ts.toInt()),
        severity: EventSeverity.parse(m['severity']),
        description: (m['description'] ?? '').toString(),
        detection: (m['detection'] ?? '').toString(),
        alarmTriggered: m['alarm'] == true,
        status: (m['status'] ?? '').toString(),
      );
    } catch (_) {
      return null;
    }
  }
}
