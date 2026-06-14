import CoreLocation
import Observation

@Observable
final class LocationTracker: NSObject, CLLocationManagerDelegate {
    var totalDistanceMeters: Double = 0
    var isAvailable = false
    var hasGpsLock = false

    var onUpdate: ((LocationUpdate) -> Void)?

    private let manager = CLLocationManager()
    private var lastLocation: CLLocation?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 5
        isAvailable = CLLocationManager.locationServicesEnabled()
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        manager.allowsBackgroundLocationUpdates = true
        manager.pausesLocationUpdatesAutomatically = false
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        // Skip inaccurate fixes to avoid cold-start drift
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy <= 25 else { return }
        hasGpsLock = true
        if let last = lastLocation {
            totalDistanceMeters += location.distance(from: last)
        }
        lastLocation = location
        onUpdate?(LocationUpdate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitudeMeters: location.verticalAccuracy >= 0 ? location.altitude : nil,
            speedMps: location.speed >= 0 ? Float(location.speed) : nil,
            timestamp: location.timestamp
        ))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        isAvailable = CLLocationManager.locationServicesEnabled() &&
            (manager.authorizationStatus == .authorizedWhenInUse ||
             manager.authorizationStatus == .authorizedAlways)
    }
}
