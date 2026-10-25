import Foundation
import CoreLocation
import MapKit
import Observation
import os

/// Observable wrapper around `CLLocationManager`.
///
/// The manager is created on the main actor (the class is `@MainActor`), so
/// CoreLocation delivers delegate callbacks on the main thread's run loop. The
/// delegate methods are therefore `nonisolated` to satisfy the Objective-C
/// protocol and use `MainActor.assumeIsolated` to touch state synchronously,
/// preserving callback ordering without an extra hop.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "LocationService")

    var currentLocation: CLLocationCoordinate2D?
    var authorizationStatus: CLAuthorizationStatus = .notDetermined
    /// Latest magnetic heading in degrees. Stored as a value (rather than the
    /// non-Sendable `CLHeading`) so it can cross into the main actor safely.
    var magneticHeading: CLLocationDirection?
    var headingAccuracy: Double = -1

    /// Last valid coordinate, persisted to disk so the app has somewhere to start
    /// when the device is offline, in the simulator, or permission has never been granted.
    var lastKnownLocation: CLLocationCoordinate2D?

    /// Filename used for the on-disk coordinate cache.
    @ObservationIgnored private let lastKnownFile = "last_known_location.json"

    /// Test seam — only set by `init(testDefaults:)`. Production path leaves it `nil`.
    @ObservationIgnored private var testDefaults: UserDefaults?

    /// Cached App Group UserDefaults to avoid recreating on every persist/restore call.
    @ObservationIgnored private let groupDefaults = UserDefaults(suiteName: "group.com.kheir.shared")

    override private init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        restoreLastKnownLocation()
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

    // MARK: - Manual override

    /// Programmatically set the current location (e.g. from geocoding a manual city)
    /// and persist it as the new last-known coordinate.
    func setLocation(_ coordinate: CLLocationCoordinate2D) {
        currentLocation = coordinate
        lastKnownLocation = coordinate
        persistLastKnownLocation(coordinate)
    }

    // MARK: - CLLocationManagerDelegate
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            guard let best = bestLocation(from: locations) else {
                logger.debug("Discarded all incoming locations as invalid")
                return
            }
            let coordinate = best.coordinate
            currentLocation = coordinate
            lastKnownLocation = coordinate
            persistLastKnownLocation(coordinate)
        }
    }

    /// Filters out CLLocation values that are obviously bogus or stale.
    /// Many problems the app has had ("prayers not showing") trace back to
    /// accepting the first fix CoreLocation hands us — which in the simulator
    /// is frequently invalid, ancient, or `horizontalAccuracy < 0`.
    /// Exposed `internal` (rather than `private`) for unit testing.
    func bestLocation(from locations: [CLLocation]) -> CLLocation? {
        let now = Date()
        return locations
            .filter { location in
                // -1 means invalid accuracy.
                guard location.horizontalAccuracy > 0 else { return false }
                // Reject fixes older than 60s — CoreLocation will sometimes replay
                // a stale coordinate immediately after startUpdatingLocation().
                guard abs(location.timestamp.timeIntervalSince(now)) < 60 else { return false }
                // Reject coordinates outside the WGS-84 valid range.
                guard CLLocationCoordinate2DIsValid(location.coordinate) else { return false }
                return true
            }
            .sorted { $0.horizontalAccuracy < $1.horizontalAccuracy }
            .first ?? locations.last
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let magnetic = newHeading.magneticHeading
        let accuracy = newHeading.headingAccuracy
        MainActor.assumeIsolated {
            magneticHeading = magnetic
            headingAccuracy = accuracy
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                startUpdating()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        logger.error("Location error: \(error.localizedDescription)")
    }

    // MARK: - Geocoding

    /// Converts a city name string into a coordinate for prayer-times calculation.
    ///
    /// Uses `MKGeocodingRequest` (iOS 26+), the replacement for the deprecated
    /// `CLGeocoder.geocodeAddressString(_:)`.  The function signature is unchanged
    /// so all existing call sites continue to work without modification.
    func geocodeCity(_ city: String) async -> CLLocationCoordinate2D? {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }
        guard let request = MKGeocodingRequest(addressString: trimmed) else {
            logger.error("Geocoding error: could not create request for '\(trimmed)'")
            return nil
        }
        do {
            let items = try await request.mapItems
            return items.first?.location.coordinate
        } catch {
            logger.error("Geocoding error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Last-known persistence

    /// Reading the saved coordinate uses the App Group container when available so
    /// the next launch (or first launch in a simulator that hasn't been granted
    /// location permission yet) has something to fall back on.
    private func sharedDefaults() -> UserDefaults? {
        groupDefaults ?? UserDefaults.standard
    }

    private func restoreLastKnownLocation() {
        restoreLastKnownLocation(from: sharedDefaults())
    }

    /// `restoreLastKnownLocation(from:)` accepts a custom defaults instance so unit tests
    /// can inject an isolated `UserDefaults(suiteName:)` without touching the App Group.
    func restoreLastKnownLocation(from defaults: UserDefaults?) {
        guard let defaults,
              let raw = defaults.data(forKey: lastKnownFile),
              let snapshot = try? JSONDecoder().decode(CoordinateSnapshot.self, from: raw) else {
            return
        }
        let coordinate = CLLocationCoordinate2D(latitude: snapshot.latitude, longitude: snapshot.longitude)
        currentLocation = coordinate
        lastKnownLocation = coordinate
    }

    private func persistLastKnownLocation(_ coordinate: CLLocationCoordinate2D) {
        persistLastKnownLocation(coordinate, to: sharedDefaults())
    }

    /// Mirrors `persistLastKnownLocation(_:)` but exposes the defaults parameter for tests.
    func persistLastKnownLocation(_ coordinate: CLLocationCoordinate2D, to defaults: UserDefaults?) {
        guard let defaults else { return }
        let snapshot = CoordinateSnapshot(latitude: coordinate.latitude, longitude: coordinate.longitude)
        do {
            let data = try JSONEncoder().encode(snapshot)
            defaults.set(data, forKey: lastKnownFile)
        } catch {
            logger.error("Failed to persist last known location: \(error.localizedDescription)")
        }
    }

    // MARK: - Test seam

    /// Designated initializer for unit tests. Avoids touching the live
    /// `CLLocationManager` delegate chain and uses an isolated
    /// `UserDefaults` suite so we can stub coordinate persistence.
    init(testDefaults: UserDefaults) {
        self.testDefaults = testDefaults
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        restoreLastKnownLocation(from: testDefaults)
    }

}

/// Sendable wrapper so we can JSON-encode CLLocationCoordinate2D.
private struct CoordinateSnapshot: Codable, Sendable {
    let latitude: Double
    let longitude: Double
}
