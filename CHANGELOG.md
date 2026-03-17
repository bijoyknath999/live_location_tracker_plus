# Changelog

## 1.0.0 — Initial Release

### Features
- **Background Location Tracking** — Android foreground service + iOS background modes
- **Real-Time Stream Updates** — Stream-based location updates via EventChannel
- **Geofencing Support** — Monitor circular regions for enter/exit/dwell events
- **Firebase Sync** — Optional automatic Firestore sync for location & geofence data
- **Battery Optimization** — Three tracking modes: High Accuracy, Balanced, Low Power
- **Permission Handling** — Built-in foreground & background permission requests
- **Dynamic Mode Switching** — Change tracking mode while actively tracking
- **Notification Permission** — Automatic POST_NOTIFICATIONS handling for Android 13+
- **Service Resilience** — Foreground service survives app close/swipe with START_STICKY
- **Boot Restart** — Auto-restart tracking after device reboot via BootCompletedReceiver

### Platforms
- Android (minSdk 24, uses FusedLocationProviderClient + ServiceCompat)
- iOS (14.0+, uses CLLocationManager)

### Example App
- Google Maps integration
- Real-time polyline route tracking
- Tap-to-add geofence regions
- Tracking mode selector
- Location stats dashboard
