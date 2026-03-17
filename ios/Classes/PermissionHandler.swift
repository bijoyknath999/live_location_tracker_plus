import Foundation
import CoreLocation

/// Handles location permission requests on iOS.
///
/// Supports both "When In Use" and "Always" authorization levels.
class LLTPermissionHandler: NSObject, CLLocationManagerDelegate {

    private let clLocationManager = CLLocationManager()
    private var permissionCallback: ((Int) -> Void)?

    override init() {
        super.init()
        clLocationManager.delegate = self
    }

    // MARK: - Public API

    /// Checks the current authorization status.
    ///
    /// Returns int matching Dart LocationPermissionStatus:
    /// 0 = notDetermined, 1 = denied, 2 = deniedForever (restricted), 3 = whileInUse, 4 = always
    func checkPermission() -> Int {
        let status: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            status = clLocationManager.authorizationStatus
        } else {
            status = CLLocationManager.authorizationStatus()
        }
        return mapAuthStatus(status)
    }

    /// Requests "When In Use" location permission.
    func requestWhenInUsePermission(completion: @escaping (Int) -> Void) {
        permissionCallback = completion
        clLocationManager.requestWhenInUseAuthorization()
    }

    /// Requests "Always" location permission for background access.
    func requestAlwaysPermission(completion: @escaping (Int) -> Void) {
        permissionCallback = completion
        clLocationManager.requestAlwaysAuthorization()
    }

    // MARK: - CLLocationManagerDelegate

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if let callback = permissionCallback {
            let status: CLAuthorizationStatus
            if #available(iOS 14.0, *) {
                status = manager.authorizationStatus
            } else {
                status = CLLocationManager.authorizationStatus()
            }

            // Only call back if not notDetermined (still waiting)
            if status != .notDetermined {
                callback(mapAuthStatus(status))
                permissionCallback = nil
            }
        }
    }

    // MARK: - Helpers

    private func mapAuthStatus(_ status: CLAuthorizationStatus) -> Int {
        switch status {
        case .notDetermined:
            return 0 // notDetermined
        case .denied:
            return 1 // denied
        case .restricted:
            return 2 // deniedForever (restricted by parental controls etc.)
        case .authorizedWhenInUse:
            return 3 // whileInUse
        case .authorizedAlways:
            return 4 // always
        @unknown default:
            return 0
        }
    }
}
