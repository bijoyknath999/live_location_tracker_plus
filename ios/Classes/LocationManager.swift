import Foundation
import CoreLocation

/// Manages continuous location tracking using CLLocationManager.
///
/// Supports background location updates, configurable accuracy,
/// distance filters, and battery optimization modes.
class LLTLocationManager: NSObject, CLLocationManagerDelegate {

    private let clLocationManager = CLLocationManager()
    private let streamHandler: LocationStreamHandler
    private let firebaseSyncManager: LLTFirebaseSyncManager?

    private var singleLocationCallback: (([String: Any?]?) -> Void)?
    private var isTracking = false

    init(streamHandler: LocationStreamHandler, firebaseSyncManager: LLTFirebaseSyncManager?) {
        self.streamHandler = streamHandler
        self.firebaseSyncManager = firebaseSyncManager
        super.init()
        clLocationManager.delegate = self
    }

    // MARK: - Public API

    /// Starts continuous location tracking.
    func startTracking(
        intervalMs: Int,
        distanceFilter: Double,
        accuracy: Int,
        trackingMode: Int,
        enableAutoPause: Bool
    ) {
        clLocationManager.desiredAccuracy = mapAccuracy(accuracy)
        clLocationManager.distanceFilter = distanceFilter
        clLocationManager.allowsBackgroundLocationUpdates = true
        clLocationManager.pausesLocationUpdatesAutomatically = enableAutoPause
        clLocationManager.showsBackgroundLocationIndicator = true

        if trackingMode == 2 {
            // Low power: use significant location changes
            clLocationManager.startMonitoringSignificantLocationChanges()
        } else {
            clLocationManager.startUpdatingLocation()
        }

        isTracking = true
    }

    /// Stops location tracking.
    func stopTracking() {
        clLocationManager.stopUpdatingLocation()
        clLocationManager.stopMonitoringSignificantLocationChanges()
        isTracking = false
    }

    /// Gets the current location as a one-shot callback.
    func getCurrentLocation(accuracy: Int, completion: @escaping ([String: Any?]?) -> Void) {
        singleLocationCallback = completion
        clLocationManager.desiredAccuracy = mapAccuracy(accuracy)
        clLocationManager.requestLocation()
    }

    /// Updates the tracking mode dynamically.
    func setTrackingMode(_ mode: Int) {
        guard isTracking else { return }

        // Stop current tracking
        clLocationManager.stopUpdatingLocation()
        clLocationManager.stopMonitoringSignificantLocationChanges()

        switch mode {
        case 0: // highAccuracy
            clLocationManager.desiredAccuracy = kCLLocationAccuracyBest
            clLocationManager.distanceFilter = 5.0
            clLocationManager.startUpdatingLocation()
        case 1: // balanced
            clLocationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            clLocationManager.distanceFilter = 10.0
            clLocationManager.startUpdatingLocation()
        case 2: // lowPower
            clLocationManager.startMonitoringSignificantLocationChanges()
        default:
            clLocationManager.startUpdatingLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let locationMap = locationToMap(location, isBackground: UIApplication.shared.applicationState != .active)

        // Handle single-shot request
        if let callback = singleLocationCallback {
            callback(locationMap)
            singleLocationCallback = nil
            return
        }

        // Send to stream
        streamHandler.sendLocation(locationMap)

        // Sync to Firebase if enabled
        firebaseSyncManager?.syncLocation(locationMap)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        NSLog("LiveLocationTracker: Location error: \(error.localizedDescription)")

        if let callback = singleLocationCallback {
            callback(nil)
            singleLocationCallback = nil
        }
    }

    // MARK: - Helpers

    private func mapAccuracy(_ accuracy: Int) -> CLLocationAccuracy {
        switch accuracy {
        case 0: return kCLLocationAccuracyKilometer          // low
        case 1: return kCLLocationAccuracyHundredMeters      // balanced
        case 2: return kCLLocationAccuracyNearestTenMeters   // high
        case 3: return kCLLocationAccuracyBest               // best
        default: return kCLLocationAccuracyNearestTenMeters
        }
    }

    private func locationToMap(_ location: CLLocation, isBackground: Bool) -> [String: Any?] {
        return [
            "latitude": location.coordinate.latitude,
            "longitude": location.coordinate.longitude,
            "altitude": location.altitude,
            "speed": max(0, location.speed),
            "heading": max(0, location.course),
            "accuracy": location.horizontalAccuracy,
            "timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000),
            "isFromBackground": isBackground
        ]
    }
}
