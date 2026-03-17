import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'live_location_tracker_plus_method_channel.dart';
import 'src/models.dart';

/// The interface that implementations of live_location_tracker_plus must implement.
///
/// Platform implementations should extend this class rather than implement it
/// as `LiveLocationTrackerPlusPlatform` does not consider newly added methods
/// to be breaking changes. Extending this class ensures that the subclass
/// will get the default implementation.
abstract class LiveLocationTrackerPlusPlatform extends PlatformInterface {
  LiveLocationTrackerPlusPlatform() : super(token: _token);

  static final Object _token = Object();

  static LiveLocationTrackerPlusPlatform _instance =
      MethodChannelLiveLocationTrackerPlus();

  /// The default instance of [LiveLocationTrackerPlusPlatform] to use.
  static LiveLocationTrackerPlusPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [LiveLocationTrackerPlusPlatform].
  static set instance(LiveLocationTrackerPlusPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the current platform version string.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  /// Starts background location tracking with the given configuration.
  Future<bool> startTracking(TrackingConfig config) {
    throw UnimplementedError('startTracking() has not been implemented.');
  }

  /// Stops background location tracking.
  Future<bool> stopTracking() {
    throw UnimplementedError('stopTracking() has not been implemented.');
  }

  /// Returns the current location as a single shot.
  Future<LocationData> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    throw UnimplementedError('getCurrentLocation() has not been implemented.');
  }

  /// Returns a stream of location updates.
  Stream<LocationData> getLocationStream() {
    throw UnimplementedError('getLocationStream() has not been implemented.');
  }

  /// Returns whether tracking is currently active.
  Future<bool> isTracking() {
    throw UnimplementedError('isTracking() has not been implemented.');
  }

  /// Adds a geofence region to monitor.
  Future<bool> addGeofence(GeofenceRegion region) {
    throw UnimplementedError('addGeofence() has not been implemented.');
  }

  /// Removes a previously registered geofence by its ID.
  Future<bool> removeGeofence(String id) {
    throw UnimplementedError('removeGeofence() has not been implemented.');
  }

  /// Returns all currently active geofence regions.
  Future<List<GeofenceRegion>> getActiveGeofences() {
    throw UnimplementedError('getActiveGeofences() has not been implemented.');
  }

  /// Returns a stream of geofence events (enter/exit/dwell).
  Stream<GeofenceEvent> getGeofenceEventStream() {
    throw UnimplementedError(
      'getGeofenceEventStream() has not been implemented.',
    );
  }

  /// Requests location permission from the user.
  Future<LocationPermissionStatus> requestPermission() {
    throw UnimplementedError('requestPermission() has not been implemented.');
  }

  /// Checks the current location permission status.
  Future<LocationPermissionStatus> checkPermission() {
    throw UnimplementedError('checkPermission() has not been implemented.');
  }

  /// Requests background location permission (Android 10+, iOS Always).
  Future<LocationPermissionStatus> requestBackgroundPermission() {
    throw UnimplementedError(
      'requestBackgroundPermission() has not been implemented.',
    );
  }

  /// Enables Firebase sync for location data.
  Future<bool> enableFirebaseSync(FirebaseConfig config) {
    throw UnimplementedError(
      'enableFirebaseSync() has not been implemented.',
    );
  }

  /// Disables Firebase sync.
  Future<bool> disableFirebaseSync() {
    throw UnimplementedError(
      'disableFirebaseSync() has not been implemented.',
    );
  }

  /// Sets the tracking mode (affects battery usage).
  Future<bool> setTrackingMode(TrackingMode mode) {
    throw UnimplementedError('setTrackingMode() has not been implemented.');
  }

  /// Opens the device's location settings page.
  Future<bool> openLocationSettings() {
    throw UnimplementedError(
      'openLocationSettings() has not been implemented.',
    );
  }

  /// Opens the app's settings page (for permission changes).
  Future<bool> openAppSettings() {
    throw UnimplementedError('openAppSettings() has not been implemented.');
  }
}
