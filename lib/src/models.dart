/// Data models for the live_location_tracker_plus plugin.
library;

/// Represents accuracy levels for location tracking.
enum LocationAccuracy {
  /// Low accuracy (~500m), minimal battery usage.
  low,

  /// Balanced accuracy (~100m), moderate battery usage.
  balanced,

  /// High accuracy (~10m), higher battery usage.
  high,

  /// Best available accuracy, highest battery usage.
  best,
}

/// Tracking modes that affect battery consumption.
enum TrackingMode {
  /// High frequency updates, best for navigation.
  highAccuracy,

  /// Balanced frequency, good for most use cases.
  balanced,

  /// Low frequency, uses significant location changes only.
  lowPower,
}

/// Types of geofence triggers.
enum GeofenceTrigger {
  /// Triggered when entering the geofence region.
  enter,

  /// Triggered when exiting the geofence region.
  exit,

  /// Triggered when dwelling in the geofence region.
  dwell,
}

/// Represents a location data point.
class LocationData {
  /// Latitude in degrees.
  final double latitude;

  /// Longitude in degrees.
  final double longitude;

  /// Altitude in meters above the WGS84 reference ellipsoid.
  final double? altitude;

  /// Speed in meters per second.
  final double? speed;

  /// Heading/bearing in degrees.
  final double? heading;

  /// Horizontal accuracy in meters.
  final double? accuracy;

  /// Timestamp of the location fix.
  final DateTime timestamp;

  /// Whether this location was obtained in the background.
  final bool isFromBackground;

  const LocationData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    this.heading,
    this.accuracy,
    required this.timestamp,
    this.isFromBackground = false,
  });

  /// Creates a [LocationData] from a map (used for platform channel deserialization).
  factory LocationData.fromMap(Map<String, dynamic> map) {
    return LocationData(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num).toInt(),
      ),
      isFromBackground: map['isFromBackground'] as bool? ?? false,
    );
  }

  /// Converts this [LocationData] to a map for platform channel serialization.
  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'speed': speed,
      'heading': heading,
      'accuracy': accuracy,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'isFromBackground': isFromBackground,
    };
  }

  @override
  String toString() =>
      'LocationData(lat: $latitude, lng: $longitude, accuracy: $accuracy, time: $timestamp)';
}

/// Defines a circular geofence region.
class GeofenceRegion {
  /// Unique identifier for this geofence.
  final String id;

  /// Center latitude of the geofence.
  final double latitude;

  /// Center longitude of the geofence.
  final double longitude;

  /// Radius in meters.
  final double radius;

  /// Which transitions to monitor.
  final List<GeofenceTrigger> triggers;

  /// Optional dwell time in milliseconds (for [GeofenceTrigger.dwell]).
  final int? loiteringDelayMs;

  /// Optional expiration duration in milliseconds. `null` means no expiration.
  final int? expirationDurationMs;

  const GeofenceRegion({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radius,
    this.triggers = const [GeofenceTrigger.enter, GeofenceTrigger.exit],
    this.loiteringDelayMs,
    this.expirationDurationMs,
  });

  /// Creates a [GeofenceRegion] from a map.
  factory GeofenceRegion.fromMap(Map<String, dynamic> map) {
    return GeofenceRegion(
      id: map['id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      radius: (map['radius'] as num).toDouble(),
      triggers: (map['triggers'] as List<dynamic>?)
              ?.map((t) => GeofenceTrigger.values[t as int])
              .toList() ??
          [GeofenceTrigger.enter, GeofenceTrigger.exit],
      loiteringDelayMs: map['loiteringDelayMs'] as int?,
      expirationDurationMs: map['expirationDurationMs'] as int?,
    );
  }

  /// Converts this [GeofenceRegion] to a map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'latitude': latitude,
      'longitude': longitude,
      'radius': radius,
      'triggers': triggers.map((t) => t.index).toList(),
      'loiteringDelayMs': loiteringDelayMs,
      'expirationDurationMs': expirationDurationMs,
    };
  }

  @override
  String toString() =>
      'GeofenceRegion(id: $id, lat: $latitude, lng: $longitude, radius: $radius)';
}

/// Represents a geofence event (transition).
class GeofenceEvent {
  /// The geofence region that triggered this event.
  final GeofenceRegion region;

  /// The type of trigger.
  final GeofenceTrigger triggerType;

  /// When this event occurred.
  final DateTime timestamp;

  /// Location at the time of the event (if available).
  final LocationData? location;

  const GeofenceEvent({
    required this.region,
    required this.triggerType,
    required this.timestamp,
    this.location,
  });

  /// Creates a [GeofenceEvent] from a map.
  factory GeofenceEvent.fromMap(Map<String, dynamic> map) {
    return GeofenceEvent(
      region: GeofenceRegion.fromMap(
        Map<String, dynamic>.from(map['region'] as Map),
      ),
      triggerType: GeofenceTrigger.values[map['triggerType'] as int],
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num).toInt(),
      ),
      location: map['location'] != null
          ? LocationData.fromMap(
              Map<String, dynamic>.from(map['location'] as Map),
            )
          : null,
    );
  }

  @override
  String toString() =>
      'GeofenceEvent(region: ${region.id}, trigger: $triggerType, time: $timestamp)';
}

/// Configuration for location tracking.
class TrackingConfig {
  /// Update interval in milliseconds.
  final int intervalMs;

  /// Minimum distance change (in meters) to trigger an update.
  final double distanceFilter;

  /// Desired location accuracy.
  final LocationAccuracy accuracy;

  /// Tracking mode (affects battery usage).
  final TrackingMode trackingMode;

  /// Whether to show a foreground notification (Android).
  final bool showNotification;

  /// Title for the foreground notification (Android).
  final String notificationTitle;

  /// Body text for the foreground notification (Android).
  final String notificationBody;

  /// Notification channel ID (Android).
  final String notificationChannelId;

  /// Notification icon name (Android drawable resource name).
  final String? notificationIconName;

  /// Whether to enable auto-pause when stationary.
  final bool enableAutoPause;

  const TrackingConfig({
    this.intervalMs = 5000,
    this.distanceFilter = 10.0,
    this.accuracy = LocationAccuracy.high,
    this.trackingMode = TrackingMode.balanced,
    this.showNotification = true,
    this.notificationTitle = 'Location Tracking Active',
    this.notificationBody = 'Your location is being tracked in the background',
    this.notificationChannelId = 'live_location_tracker_channel',
    this.notificationIconName,
    this.enableAutoPause = true,
  });

  /// Converts this config to a map for platform channel serialization.
  Map<String, dynamic> toMap() {
    return {
      'intervalMs': intervalMs,
      'distanceFilter': distanceFilter,
      'accuracy': accuracy.index,
      'trackingMode': trackingMode.index,
      'showNotification': showNotification,
      'notificationTitle': notificationTitle,
      'notificationBody': notificationBody,
      'notificationChannelId': notificationChannelId,
      'notificationIconName': notificationIconName,
      'enableAutoPause': enableAutoPause,
    };
  }
}

/// Configuration for Firebase sync.
class FirebaseConfig {
  /// Firestore collection path for storing location data.
  final String collectionPath;

  /// Unique user identifier for document path.
  final String userId;

  /// Whether to sync location updates.
  final bool enableLocationSync;

  /// Whether to sync geofence events.
  final bool enableGeofenceSync;

  /// Minimum interval between syncs in milliseconds (batching).
  final int syncIntervalMs;

  const FirebaseConfig({
    this.collectionPath = 'live_locations',
    required this.userId,
    this.enableLocationSync = true,
    this.enableGeofenceSync = true,
    this.syncIntervalMs = 10000,
  });

  /// Converts this config to a map.
  Map<String, dynamic> toMap() {
    return {
      'collectionPath': collectionPath,
      'userId': userId,
      'enableLocationSync': enableLocationSync,
      'enableGeofenceSync': enableGeofenceSync,
      'syncIntervalMs': syncIntervalMs,
    };
  }
}

/// Represents the current permission status for location.
enum LocationPermissionStatus {
  /// Permission has not been requested yet.
  notDetermined,

  /// Permission denied by user.
  denied,

  /// Permission permanently denied (user must change in settings).
  deniedForever,

  /// Permission granted for foreground only.
  whileInUse,

  /// Permission granted for both foreground and background.
  always,
}
