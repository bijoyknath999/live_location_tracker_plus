import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'live_location_tracker_plus_platform_interface.dart';
import 'src/models.dart';

/// An implementation of [LiveLocationTrackerPlusPlatform] that uses
/// method channels and event channels for native communication.
class MethodChannelLiveLocationTrackerPlus
    extends LiveLocationTrackerPlusPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('live_location_tracker_plus');

  /// Event channel for streaming location updates.
  @visibleForTesting
  final locationEventChannel =
      const EventChannel('live_location_tracker_plus/location_stream');

  /// Event channel for streaming geofence events.
  @visibleForTesting
  final geofenceEventChannel =
      const EventChannel('live_location_tracker_plus/geofence_stream');

  Stream<LocationData>? _locationStream;
  Stream<GeofenceEvent>? _geofenceStream;

  @override
  Future<String?> getPlatformVersion() async {
    final version =
        await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<bool> startTracking(TrackingConfig config) async {
    final result = await methodChannel.invokeMethod<bool>(
      'startTracking',
      config.toMap(),
    );
    return result ?? false;
  }

  @override
  Future<bool> stopTracking() async {
    final result = await methodChannel.invokeMethod<bool>('stopTracking');
    // Reset cached streams when tracking stops.
    _locationStream = null;
    return result ?? false;
  }

  @override
  Future<LocationData> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) async {
    final result = await methodChannel.invokeMethod<Map>(
      'getCurrentLocation',
      {'accuracy': accuracy.index},
    );
    if (result == null) {
      throw PlatformException(
        code: 'LOCATION_ERROR',
        message: 'Failed to get current location',
      );
    }
    return LocationData.fromMap(Map<String, dynamic>.from(result));
  }

  @override
  Stream<LocationData> getLocationStream() {
    _locationStream ??= locationEventChannel
        .receiveBroadcastStream()
        .map((event) =>
            LocationData.fromMap(Map<String, dynamic>.from(event as Map)))
        .handleError((error) {
      debugPrint('LiveLocationTracker: Location stream error: $error');
    });
    return _locationStream!;
  }

  @override
  Future<bool> isTracking() async {
    final result = await methodChannel.invokeMethod<bool>('isTracking');
    return result ?? false;
  }

  @override
  Future<bool> addGeofence(GeofenceRegion region) async {
    final result = await methodChannel.invokeMethod<bool>(
      'addGeofence',
      region.toMap(),
    );
    return result ?? false;
  }

  @override
  Future<bool> removeGeofence(String id) async {
    final result = await methodChannel.invokeMethod<bool>(
      'removeGeofence',
      {'id': id},
    );
    return result ?? false;
  }

  @override
  Future<List<GeofenceRegion>> getActiveGeofences() async {
    final result =
        await methodChannel.invokeMethod<List>('getActiveGeofences');
    if (result == null) return [];
    return result
        .map((item) =>
            GeofenceRegion.fromMap(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  @override
  Stream<GeofenceEvent> getGeofenceEventStream() {
    _geofenceStream ??= geofenceEventChannel
        .receiveBroadcastStream()
        .map((event) =>
            GeofenceEvent.fromMap(Map<String, dynamic>.from(event as Map)))
        .handleError((error) {
      debugPrint('LiveLocationTracker: Geofence stream error: $error');
    });
    return _geofenceStream!;
  }

  @override
  Future<LocationPermissionStatus> requestPermission() async {
    final result =
        await methodChannel.invokeMethod<int>('requestPermission');
    return LocationPermissionStatus.values[result ?? 0];
  }

  @override
  Future<LocationPermissionStatus> checkPermission() async {
    final result =
        await methodChannel.invokeMethod<int>('checkPermission');
    return LocationPermissionStatus.values[result ?? 0];
  }

  @override
  Future<LocationPermissionStatus> requestBackgroundPermission() async {
    final result =
        await methodChannel.invokeMethod<int>('requestBackgroundPermission');
    return LocationPermissionStatus.values[result ?? 0];
  }

  @override
  Future<bool> enableFirebaseSync(FirebaseConfig config) async {
    final result = await methodChannel.invokeMethod<bool>(
      'enableFirebaseSync',
      config.toMap(),
    );
    return result ?? false;
  }

  @override
  Future<bool> disableFirebaseSync() async {
    final result =
        await methodChannel.invokeMethod<bool>('disableFirebaseSync');
    return result ?? false;
  }

  @override
  Future<bool> setTrackingMode(TrackingMode mode) async {
    final result = await methodChannel.invokeMethod<bool>(
      'setTrackingMode',
      {'mode': mode.index},
    );
    return result ?? false;
  }

  @override
  Future<bool> openLocationSettings() async {
    final result =
        await methodChannel.invokeMethod<bool>('openLocationSettings');
    return result ?? false;
  }

  @override
  Future<bool> openAppSettings() async {
    final result = await methodChannel.invokeMethod<bool>('openAppSettings');
    return result ?? false;
  }
}
