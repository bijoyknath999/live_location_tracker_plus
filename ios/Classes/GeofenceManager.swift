import Foundation
import CoreLocation

/// Manages geofence region monitoring using CLLocationManager.
///
/// Supports up to 20 simultaneous geofence regions on iOS.
class LLTGeofenceManager: NSObject, CLLocationManagerDelegate {

    private let clLocationManager = CLLocationManager()
    private let streamHandler: GeofenceStreamHandler

    // Cache active geofences for getActiveGeofences()
    private var activeGeofences: [String: [String: Any?]] = [:]

    init(streamHandler: GeofenceStreamHandler) {
        self.streamHandler = streamHandler
        super.init()
        clLocationManager.delegate = self
    }

    // MARK: - Public API

    /// Adds a circular geofence region to monitor.
    func addGeofence(
        id: String,
        latitude: Double,
        longitude: Double,
        radius: Double,
        triggers: [Int]
    ) -> Bool {
        guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
            NSLog("LiveLocationTracker: Geofence monitoring not available on this device")
            return false
        }

        // iOS supports max ~20 regions
        if clLocationManager.monitoredRegions.count >= 20 {
            NSLog("LiveLocationTracker: Maximum geofence regions reached (20)")
            return false
        }

        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let clampedRadius = min(radius, clLocationManager.maximumRegionMonitoringDistance)
        let region = CLCircularRegion(center: center, radius: clampedRadius, identifier: id)

        // Configure triggers
        region.notifyOnEntry = triggers.contains(0)
        region.notifyOnExit = triggers.contains(1)
        // iOS doesn't have native dwell—we'd need custom logic for that

        clLocationManager.startMonitoring(for: region)

        activeGeofences[id] = [
            "id": id,
            "latitude": latitude,
            "longitude": longitude,
            "radius": radius,
            "triggers": triggers
        ]

        NSLog("LiveLocationTracker: Geofence added: \(id)")
        return true
    }

    /// Removes a monitored geofence region by its ID.
    func removeGeofence(id: String) -> Bool {
        for region in clLocationManager.monitoredRegions {
            if region.identifier == id {
                clLocationManager.stopMonitoring(for: region)
                activeGeofences.removeValue(forKey: id)
                NSLog("LiveLocationTracker: Geofence removed: \(id)")
                return true
            }
        }
        return false
    }

    /// Returns all active geofence regions.
    func getActiveGeofences() -> [[String: Any?]] {
        return Array(activeGeofences.values)
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        sendGeofenceEvent(region: circularRegion, triggerType: 0) // enter
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        guard let circularRegion = region as? CLCircularRegion else { return }
        sendGeofenceEvent(region: circularRegion, triggerType: 1) // exit
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        NSLog("LiveLocationTracker: Geofence monitoring failed for \(region?.identifier ?? "unknown"): \(error.localizedDescription)")
    }

    // MARK: - Helpers

    private func sendGeofenceEvent(region: CLCircularRegion, triggerType: Int) {
        let eventMap: [String: Any?] = [
            "region": [
                "id": region.identifier,
                "latitude": region.center.latitude,
                "longitude": region.center.longitude,
                "radius": region.radius,
                "triggers": [triggerType]
            ],
            "triggerType": triggerType,
            "timestamp": Int64(Date().timeIntervalSince1970 * 1000),
            "location": nil
        ]

        DispatchQueue.main.async { [weak self] in
            self?.streamHandler.sendGeofenceEvent(eventMap)
        }
    }
}
