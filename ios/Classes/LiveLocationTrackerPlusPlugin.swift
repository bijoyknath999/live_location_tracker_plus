import Flutter
import UIKit
import CoreLocation

/// Main Flutter plugin class for live_location_tracker_plus on iOS.
///
/// Handles method channel routing, event channel streams, and delegates
/// to specialized managers for location, geofencing, Firebase sync, and permissions.
public class LiveLocationTrackerPlusPlugin: NSObject, FlutterPlugin {

    private var channel: FlutterMethodChannel?
    private var locationEventChannel: FlutterEventChannel?
    private var geofenceEventChannel: FlutterEventChannel?

    private var locationManager: LLTLocationManager?
    private var geofenceManager: LLTGeofenceManager?
    private var permissionHandler: LLTPermissionHandler?
    private var firebaseSyncManager: LLTFirebaseSyncManager?

    private let locationStreamHandler = LocationStreamHandler()
    private let geofenceStreamHandler = GeofenceStreamHandler()

    private var isTrackingActive = false

    override init() {
        channel = nil
        locationEventChannel = nil
        geofenceEventChannel = nil
        locationManager = nil
        geofenceManager = nil
        permissionHandler = nil
        firebaseSyncManager = nil
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = LiveLocationTrackerPlusPlugin()

        // Method channel
        let channel = FlutterMethodChannel(
            name: "live_location_tracker_plus",
            binaryMessenger: registrar.messenger()
        )
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Location event channel
        let locationEC = FlutterEventChannel(
            name: "live_location_tracker_plus/location_stream",
            binaryMessenger: registrar.messenger()
        )
        locationEC.setStreamHandler(instance.locationStreamHandler)
        instance.locationEventChannel = locationEC

        // Geofence event channel
        let geofenceEC = FlutterEventChannel(
            name: "live_location_tracker_plus/geofence_stream",
            binaryMessenger: registrar.messenger()
        )
        geofenceEC.setStreamHandler(instance.geofenceStreamHandler)
        instance.geofenceEventChannel = geofenceEC

        // Initialize managers
        instance.firebaseSyncManager = LLTFirebaseSyncManager()
        instance.locationManager = LLTLocationManager(
            streamHandler: instance.locationStreamHandler,
            firebaseSyncManager: instance.firebaseSyncManager
        )
        instance.geofenceManager = LLTGeofenceManager(
            streamHandler: instance.geofenceStreamHandler
        )
        instance.permissionHandler = LLTPermissionHandler()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)

        case "startTracking":
            handleStartTracking(call: call, result: result)

        case "stopTracking":
            handleStopTracking(result: result)

        case "getCurrentLocation":
            handleGetCurrentLocation(call: call, result: result)

        case "isTracking":
            result(isTrackingActive)

        case "addGeofence":
            handleAddGeofence(call: call, result: result)

        case "removeGeofence":
            handleRemoveGeofence(call: call, result: result)

        case "getActiveGeofences":
            handleGetActiveGeofences(result: result)

        case "requestPermission":
            handleRequestPermission(result: result)

        case "checkPermission":
            handleCheckPermission(result: result)

        case "requestBackgroundPermission":
            handleRequestBackgroundPermission(result: result)

        case "enableFirebaseSync":
            handleEnableFirebaseSync(call: call, result: result)

        case "disableFirebaseSync":
            handleDisableFirebaseSync(result: result)

        case "setTrackingMode":
            handleSetTrackingMode(call: call, result: result)

        case "openLocationSettings":
            handleOpenLocationSettings(result: result)

        case "openAppSettings":
            handleOpenAppSettings(result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Tracking

    private func handleStartTracking(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(false)
            return
        }

        let intervalMs = args["intervalMs"] as? Int ?? 5000
        let distanceFilter = args["distanceFilter"] as? Double ?? 10.0
        let accuracy = args["accuracy"] as? Int ?? 2
        let trackingMode = args["trackingMode"] as? Int ?? 1
        let enableAutoPause = args["enableAutoPause"] as? Bool ?? true

        locationManager?.startTracking(
            intervalMs: intervalMs,
            distanceFilter: distanceFilter,
            accuracy: accuracy,
            trackingMode: trackingMode,
            enableAutoPause: enableAutoPause
        )

        isTrackingActive = true
        result(true)
    }

    private func handleStopTracking(result: @escaping FlutterResult) {
        locationManager?.stopTracking()
        isTrackingActive = false
        result(true)
    }

    private func handleGetCurrentLocation(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]
        let accuracy = args?["accuracy"] as? Int ?? 2

        locationManager?.getCurrentLocation(accuracy: accuracy) { locationMap in
            if let locationMap = locationMap {
                result(locationMap)
            } else {
                result(FlutterError(code: "LOCATION_ERROR",
                                   message: "Failed to get current location",
                                   details: nil))
            }
        }
    }

    private func handleSetTrackingMode(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let mode = args["mode"] as? Int else {
            result(false)
            return
        }
        locationManager?.setTrackingMode(mode)
        result(true)
    }

    // MARK: - Geofencing

    private func handleAddGeofence(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let id = args["id"] as? String,
              let latitude = args["latitude"] as? Double,
              let longitude = args["longitude"] as? Double,
              let radius = args["radius"] as? Double else {
            result(false)
            return
        }

        let triggers = args["triggers"] as? [Int] ?? [0, 1]

        let success = geofenceManager?.addGeofence(
            id: id,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            triggers: triggers
        ) ?? false

        result(success)
    }

    private func handleRemoveGeofence(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let id = args["id"] as? String else {
            result(false)
            return
        }
        let success = geofenceManager?.removeGeofence(id: id) ?? false
        result(success)
    }

    private func handleGetActiveGeofences(result: @escaping FlutterResult) {
        let geofences = geofenceManager?.getActiveGeofences() ?? []
        result(geofences)
    }

    // MARK: - Permissions

    private func handleRequestPermission(result: @escaping FlutterResult) {
        permissionHandler?.requestWhenInUsePermission { status in
            result(status)
        }
    }

    private func handleCheckPermission(result: @escaping FlutterResult) {
        let status = permissionHandler?.checkPermission() ?? 0
        result(status)
    }

    private func handleRequestBackgroundPermission(result: @escaping FlutterResult) {
        permissionHandler?.requestAlwaysPermission { status in
            result(status)
        }
    }

    // MARK: - Firebase Sync

    private func handleEnableFirebaseSync(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let userId = args["userId"] as? String else {
            result(false)
            return
        }

        let collectionPath = args["collectionPath"] as? String ?? "live_locations"
        let syncIntervalMs = args["syncIntervalMs"] as? Int ?? 10000

        let success = firebaseSyncManager?.enable(
            collectionPath: collectionPath,
            userId: userId,
            syncIntervalMs: syncIntervalMs
        ) ?? false

        result(success)
    }

    private func handleDisableFirebaseSync(result: @escaping FlutterResult) {
        firebaseSyncManager?.disable()
        result(true)
    }

    // MARK: - Settings

    private func handleOpenLocationSettings(result: @escaping FlutterResult) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:]) { success in
                    result(success)
                }
            }
        } else {
            result(false)
        }
    }

    private func handleOpenAppSettings(result: @escaping FlutterResult) {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            DispatchQueue.main.async {
                UIApplication.shared.open(url, options: [:]) { success in
                    result(success)
                }
            }
        } else {
            result(false)
        }
    }
}

// MARK: - Stream Handlers

/// Stream handler for location updates sent to Flutter.
class LocationStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    override init() {
        eventSink = nil
        super.init()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func sendLocation(_ locationMap: [String: Any?]) {
        eventSink?(locationMap)
    }
}

/// Stream handler for geofence events sent to Flutter.
class GeofenceStreamHandler: NSObject, FlutterStreamHandler {
    private var eventSink: FlutterEventSink?

    override init() {
        eventSink = nil
        super.init()
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    func sendGeofenceEvent(_ eventMap: [String: Any?]) {
        eventSink?(eventMap)
    }
}
