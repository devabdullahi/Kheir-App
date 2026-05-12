import Foundation
import CoreLocation
import Combine
import os

@MainActor
final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    private let manager = CLLocationManager()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "LocationService")

    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var heading: CLHeading?
    @Published var headingAccuracy: Double = -1

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 100
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        manager.startUpdatingLocation()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
    }

    func startHeadingUpdates() {
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stopHeadingUpdates() {
        manager.stopUpdatingHeading()
    }

    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.last?.coordinate
        DispatchQueue.main.async {
            self.currentLocation = coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let accuracy = newHeading.headingAccuracy
        DispatchQueue.main.async {
            self.heading = newHeading
            self.headingAccuracy = accuracy
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        DispatchQueue.main.async {
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.startUpdating()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location error: \(error.localizedDescription)")
    }

    // MARK: - Geocoding
    func geocodeCity(_ city: String) async -> CLLocationCoordinate2D? {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(trimmed)
            return placemarks.first?.location?.coordinate
        } catch {
            logger.error("Geocoding error: \(error.localizedDescription)")
            return nil
        }
    }
}
