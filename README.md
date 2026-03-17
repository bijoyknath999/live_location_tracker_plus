# Live Location Tracker Plus 🗺️

A powerful Flutter plugin for **real-time background location tracking** with geofencing, Firebase sync, and battery optimization — supporting both **Android** and **iOS**.

[![pub package](https://img.shields.io/pub/v/live_location_tracker_plus.svg)](https://pub.dev/packages/live_location_tracker_plus)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-blue.svg)](https://pub.dev/packages/live_location_tracker_plus)
[![Flutter](https://img.shields.io/badge/Flutter-%3E%3D3.3.0-02569B.svg)](https://flutter.dev)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| 📍 **Background Location Tracking** | Continuous GPS tracking even when the app is in background |
| 🔄 **Real-Time Stream Updates** | Stream-based location updates via `EventChannel` |
| 📡 **Geofencing** | Monitor enter/exit/dwell events for circular regions |
| 🔥 **Firebase Sync** | Automatic Firestore sync for location & geofence events |
| 🔋 **Battery Optimization** | Three tracking modes: High Accuracy, Balanced, Low Power |
| 🔐 **Permission Handling** | Built-in permission requests with status checking |
| 🤖 **Android Foreground Service** | Persistent notification for reliable background tracking |
| 🍎 **iOS Background Modes** | CLLocationManager with significant location changes |

---

## 📦 Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  live_location_tracker_plus: ^1.0.0
```

Then run:

```bash
flutter pub get
```

---

## 🗝️ Google Maps API Key Setup

The example app uses Google Maps. You need an API key for both Android and iOS.

### How to Get a Key

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project (or select an existing one)
3. Navigate to **APIs & Services → Library**
4. Enable **"Maps SDK for Android"** and **"Maps SDK for iOS"**
5. Go to **APIs & Services → Credentials**
6. Click **Create Credentials → API Key**
7. Copy the generated key

### Add the Key to Android

In `android/app/src/main/AndroidManifest.xml`, inside the `<application>` tag:

```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_API_KEY_HERE" />
```

### Add the Key to iOS

In `ios/Runner/AppDelegate.swift`, add the import and provide the key:

```swift
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_API_KEY_HERE")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

---

## 🤖 Android Setup

### 1. Permissions

Add to your app's `AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

> **Note:** `POST_NOTIFICATIONS` is required for Android 13+ to show the foreground service notification. The plugin requests this permission automatically at runtime.

### 2. Firebase (optional)

If using Firebase sync, add `google-services.json` to `android/app/` and include:

```gradle
// android/build.gradle
dependencies {
    classpath 'com.google.gms:google-services:4.4.0'
}

// android/app/build.gradle
apply plugin: 'com.google.gms.google-services'

dependencies {
    implementation 'com.google.firebase:firebase-firestore'
}
```

---

## 🍎 iOS Setup

### 1. Info.plist

Add these keys to `ios/Runner/Info.plist`:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>We need your location to track your real-time position.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>We need background location access to track your position continuously.</string>

<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

### 2. Firebase (optional)

Add `GoogleService-Info.plist` to the Runner target and include in `Podfile`:

```ruby
pod 'FirebaseFirestore'
```

---

## 🚀 Quick Start

```dart
import 'package:live_location_tracker_plus/live_location_tracker_plus.dart';

final tracker = LiveLocationTrackerPlus();

// 1. Request permission
final status = await tracker.requestPermission();
if (status == LocationPermissionStatus.denied) {
  // Handle denial
  return;
}

// 2. Request background permission
await tracker.requestBackgroundPermission();

// 3. Start tracking
await tracker.startTracking(TrackingConfig(
  intervalMs: 5000,
  distanceFilter: 10.0,
  accuracy: LocationAccuracy.high,
  trackingMode: TrackingMode.balanced,
  notificationTitle: 'Tracking Active',       // Android only
  notificationBody: 'Your location is live',  // Android only
));

// 4. Listen to location updates
tracker.locationStream.listen((location) {
  print('📍 ${location.latitude}, ${location.longitude}');
  print('   Accuracy: ${location.accuracy}m');
  print('   Speed: ${location.speed} m/s');
});

// 5. Stop tracking
await tracker.stopTracking();
```

---

## 📡 Geofencing

```dart
// Add a geofence
await tracker.addGeofence(GeofenceRegion(
  id: 'office',
  latitude: 23.8103,
  longitude: 90.4125,
  radius: 200, // meters
  triggers: [GeofenceTrigger.enter, GeofenceTrigger.exit],
));

// Listen to events
tracker.geofenceEventStream.listen((event) {
  print('Geofence ${event.region.id}: ${event.triggerType}');
});

// Remove a geofence
await tracker.removeGeofence('office');
```

> **Note:** Android supports up to 100 geofences, iOS supports up to 20.

---

## 🔥 Firebase Sync

```dart
// Enable automatic Firestore sync
await tracker.enableFirebaseSync(FirebaseConfig(
  collectionPath: 'live_locations',
  userId: 'user_123',
  syncIntervalMs: 10000,  // Batch updates every 10s
  enableLocationSync: true,
  enableGeofenceSync: true,
));

// Data is written to: live_locations/{userId}/locations/
// Geofence events: live_locations/{userId}/geofence_events/

// Disable sync
await tracker.disableFirebaseSync();
```

> **Important:** Firebase must be initialized in your app first. The plugin uses it as an optional dependency.

---

## 🔋 Battery Optimization

```dart
// Switch modes dynamically (even while tracking)
await tracker.setTrackingMode(TrackingMode.highAccuracy); // ~2s updates
await tracker.setTrackingMode(TrackingMode.balanced);     // ~5s updates
await tracker.setTrackingMode(TrackingMode.lowPower);     // Significant changes only
```

| Mode | Android | iOS | Battery |
|------|---------|-----|---------|
| `highAccuracy` | GPS, 2s interval | `kCLLocationAccuracyBest` | 🔴 High |
| `balanced` | GPS, 5s interval | `kCLLocationAccuracyNearestTenMeters` | 🟡 Medium |
| `lowPower` | 30s+ interval | Significant location changes | 🟢 Low |

---

## 📋 API Reference

| Method | Returns | Description |
|--------|---------|-------------|
| `startTracking(config)` | `Future<bool>` | Starts background tracking |
| `stopTracking()` | `Future<bool>` | Stops tracking |
| `getCurrentLocation()` | `Future<LocationData>` | Single-shot location |
| `locationStream` | `Stream<LocationData>` | Continuous location stream |
| `isTracking` | `Future<bool>` | Check if tracking is active |
| `addGeofence(region)` | `Future<bool>` | Register a geofence |
| `removeGeofence(id)` | `Future<bool>` | Remove a geofence |
| `geofenceEventStream` | `Stream<GeofenceEvent>` | Geofence transition events |
| `requestPermission()` | `Future<Status>` | Request foreground permission |
| `requestBackgroundPermission()` | `Future<Status>` | Request background permission |
| `checkPermission()` | `Future<Status>` | Check current permission |
| `enableFirebaseSync(config)` | `Future<bool>` | Enable Firestore sync |
| `disableFirebaseSync()` | `Future<bool>` | Disable Firestore sync |
| `setTrackingMode(mode)` | `Future<bool>` | Change battery mode |
| `openLocationSettings()` | `Future<bool>` | Open device location settings |
| `openAppSettings()` | `Future<bool>` | Open app settings page |

---

## 📱 Example App

The example app demonstrates all features with a Google Maps UI:

- Real-time location tracking with polyline route
- Tap-to-add geofence regions
- Three battery mode options
- Permission status display
- Location stats dashboard

Run the example:

```bash
cd example
flutter run
```

---

## 🚀 Publishing

This package uses **GitHub Actions** for automated publishing to pub.dev. To release a new version:

```bash
# 1. Update version in pubspec.yaml (e.g. 1.0.2)
# 2. Update CHANGELOG.md with what's new
# 3. Commit your changes
git add -A && git commit -m "v1.0.2"

# 4. Create a version tag
git tag v1.0.2

# 5. Push with tags — this auto-publishes to pub.dev!
git push origin main --tags
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
