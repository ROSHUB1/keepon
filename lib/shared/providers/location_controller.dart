import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../integrations/android/native_bridge.dart';
import '../models/location_record.dart';
import '../models/permission_state.dart';
import '../models/security_event.dart';
import 'protection_controller.dart';
import 'providers.dart';

class LocationState {
  const LocationState({this.record, this.busy = false, this.message});

  final LocationRecord? record;
  final bool busy;
  final String? message;
}

class LocationController extends Notifier<LocationState> {
  @override
  LocationState build() => LocationState(record: ref.read(storageProvider).loadLocation());

  /// Reads the real location from Android (only when the user asks) and saves it locally.
  Future<void> update() async {
    if (state.busy) return;
    state = LocationState(record: state.record, busy: true);
    final bridge = ref.read(bridgeProvider);
    var perm = await bridge.permissionStatus('location');
    if (perm != PermStatus.granted) perm = await bridge.requestPermission('location');
    await ref.read(protectionProvider.notifier).refreshPermissions();
    if (perm != PermStatus.granted) {
      await ref.read(eventsProvider.notifier).record(
            EventType.permissionUnavailable,
            severity: EventSeverity.attention,
            description: 'Location permission is not available, so the last location could not be updated.',
            detection: 'Location permission: ${perm.name}',
          );
      state = LocationState(
        record: state.record,
        message: perm == PermStatus.permanentlyDenied
            ? 'Location is blocked for KEEPON. Open Android settings to allow it.'
            : 'Location permission was not granted.',
      );
      return;
    }
    try {
      final r = await bridge.getLocation();
      final ok = await ref.read(storageProvider).saveLocation(r);
      state = LocationState(
        record: r,
        message: ok ? null : 'The location was found but could not be saved on this device.',
      );
    } on NativeFailure catch (e) {
      state = LocationState(record: state.record, message: e.message);
    }
  }
}

final locationProvider = NotifierProvider<LocationController, LocationState>(LocationController.new);
