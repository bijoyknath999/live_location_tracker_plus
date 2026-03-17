/// A Flutter plugin for live location tracking with background support,
/// geofencing, Firebase sync, and battery optimization.
///
/// ## Getting Started
///
/// ```dart
/// import 'package:live_location_tracker_plus/live_location_tracker_plus.dart';
///
/// final tracker = LiveLocationTrackerPlus();
///
/// // Request permission
/// final status = await tracker.requestPermission();
///
/// // Start tracking
/// await tracker.startTracking(TrackingConfig(
///   intervalMs: 5000,
///   distanceFilter: 10.0,
///   accuracy: LocationAccuracy.high,
/// ));
///
/// // Listen to updates
/// tracker.locationStream.listen((location) {
///   print('${location.latitude}, ${location.longitude}');
/// });
/// ```
library;

export 'src/models.dart';

import 'live_location_tracker_plus_platform_interface.dart';
import 'src/models.dart';

/// The main entry point for the Live Location Tracker Plus plugin.
///
/// Provides methods for:
/// - Background location tracking with real-time stream updates
/// - Geofence monitoring (enter/exit/dwell)
/// - Firebase Firestore sync
/// - Battery-optimized tracking modes
/// - Permission handling
class LiveLocationTrackerPlus {
  // ---------------------------------------------------------------------------
  // Platform Info
  // ---------------------------------------------------------------------------

  /// Returns the platform version string.
  Future<String?> getPlatformVersion() {
    return LiveLocationTrackerPlusPlatform.instance.getPlatformVersion();
  }

  // ---------------------------------------------------------------------------
  // Location Tracking
  // ---------------------------------------------------------------------------

  /// Starts background location tracking with the given [config].
  ///
  /// Returns `true` if tracking started successfully.
  /// On Android, this starts a foreground service with a persistent notification.
  /// On iOS, this enables background location updates.
  Future<bool> startTracking([TrackingConfig config = const TrackingConfig()]) {
    return LiveLocationTrackerPlusPlatform.instance.startTracking(config);
  }

  /// Stops background location tracking.
  ///
  /// Returns `true` if tracking was stopped successfully.
  Future<bool> stopTracking() {
    return LiveLocationTrackerPlusPlatform.instance.stopTracking();
  }

  /// Gets the current location as a single shot.
  ///
  /// This does not require tracking to be started.
  Future<LocationData> getCurrentLocation({
    LocationAccuracy accuracy = LocationAccuracy.high,
  }) {
    return LiveLocationTrackerPlusPlatform.instance
        .getCurrentLocation(accuracy: accuracy);
  }

  /// Returns a broadcast stream of location updates.
  ///
  /// Tracking must be started via [startTracking] first for this stream to emit.
  Stream<LocationData> get locationStream {
    return LiveLocationTrackerPlusPlatform.instance.getLocationStream();
  }

  /// Returns whether location tracking is currently active.
  Future<bool> get isTracking {
    return LiveLocationTrackerPlusPlatform.instance.isTracking();
  }

  /// Sets the tracking mode to adjust battery vs accuracy tradeoff.
  ///
  /// Can be called while tracking is active to dynamically change the mode.
  Future<bool> setTrackingMode(TrackingMode mode) {
    return LiveLocationTrackerPlusPlatform.instance.setTrackingMode(mode);
  }

  // ---------------------------------------------------------------------------
  // Geofencing
  // ---------------------------------------------------------------------------

  /// Adds a geofence [region] to monitor.
  ///
  /// Returns `true` if the geofence was registered successfully.
  /// Android supports up to 100 geofences, iOS supports up to 20.
  Future<bool> addGeofence(GeofenceRegion region) {
    return LiveLocationTrackerPlusPlatform.instance.addGeofence(region);
  }

  /// Removes a previously registered geofence by its [id].
  Future<bool> removeGeofence(String id) {
    return LiveLocationTrackerPlusPlatform.instance.removeGeofence(id);
  }

  /// Returns all currently active/registered geofence regions.
  Future<List<GeofenceRegion>> getActiveGeofences() {
    return LiveLocationTrackerPlusPlatform.instance.getActiveGeofences();
  }

  /// Returns a broadcast stream of geofence transition events.
  Stream<GeofenceEvent> get geofenceEventStream {
    return LiveLocationTrackerPlusPlatform.instance.getGeofenceEventStream();
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// Requests location permission from the user.
  ///
  /// On first call, requests "When In Use" permission.
  /// Use [requestBackgroundPermission] for background/always access.
  Future<LocationPermissionStatus> requestPermission() {
    return LiveLocationTrackerPlusPlatform.instance.requestPermission();
  }

  /// Checks the current location permission status without prompting.
  Future<LocationPermissionStatus> checkPermission() {
    return LiveLocationTrackerPlusPlatform.instance.checkPermission();
  }

  /// Requests background location permission.
  ///
  /// On Android 10+, this shows the "Allow all the time" dialog.
  /// On iOS, this upgrades from "When In Use" to "Always" authorization.
  ///
  /// **Important:** Call [requestPermission] first before calling this.
  Future<LocationPermissionStatus> requestBackgroundPermission() {
    return LiveLocationTrackerPlusPlatform.instance
        .requestBackgroundPermission();
  }

  /// Opens the device's location settings page.
  Future<bool> openLocationSettings() {
    return LiveLocationTrackerPlusPlatform.instance.openLocationSettings();
  }

  /// Opens the app's settings page (for changing permissions).
  Future<bool> openAppSettings() {
    return LiveLocationTrackerPlusPlatform.instance.openAppSettings();
  }

  // ---------------------------------------------------------------------------
  // Firebase Sync
  // ---------------------------------------------------------------------------

  /// Enables automatic Firebase Firestore sync for location updates.
  ///
  /// Location data will be written to: `{collectionPath}/{userId}/locations/`.
  /// Requires Firebase to be initialized in the host app.
  Future<bool> enableFirebaseSync(FirebaseConfig config) {
    return LiveLocationTrackerPlusPlatform.instance.enableFirebaseSync(config);
  }

  /// Disables Firebase sync.
  Future<bool> disableFirebaseSync() {
    return LiveLocationTrackerPlusPlatform.instance.disableFirebaseSync();
  }
}
