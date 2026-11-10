import Foundation
import MapKit
import SwiftUI
import UIKit
import os

@MainActor
@Observable
final class MasjidFinderViewModel {
    var masjids: [MasjidItem] = []
    var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    var isLoading = false
    var searchRadius: SearchRadius = .fiveKm
    var viewMode: ViewMode = .split
    var locationDenied = false

    private static let metersPerMile: Double = 1609.34

    private let locationService = LocationService.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "MasjidFinder")
    @ObservationIgnored private var firstLocationTask: Task<Void, Never>?
    @ObservationIgnored private var authorizationTask: Task<Void, Never>?

    deinit {
        firstLocationTask?.cancel()
        authorizationTask?.cancel()
    }

    enum ViewMode: String, CaseIterable {
        case split = "Split"
        case map = "Map"
    }

    enum SearchRadius: Double, CaseIterable {
        case oneKm = 1000
        case fiveKm = 5000
        case tenKm = 10000
        case twentyFiveKm = 25000

        var displayName: String {
            switch self {
            case .oneKm: return "1 km"
            case .fiveKm: return "5 km"
            case .tenKm: return "10 km"
            case .twentyFiveKm: return "25 km"
            }
        }
    }

    func onAppear() {
        locationService.requestPermission()
        locationService.startUpdating()

        // React to the first non-nil location (the sequence emits the current
        // value immediately, then on each change) and to authorization changes.
        let locationService = locationService
        firstLocationTask?.cancel()
        firstLocationTask = Task { [weak self] in
            for await coordinate in Observations({ locationService.currentLocation }) {
                guard let coordinate else { continue }
                guard let self else { return }
                self.region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                await self.searchMasjids(near: coordinate)
                return
            }
        }

        authorizationTask?.cancel()
        authorizationTask = Task { [weak self] in
            for await status in Observations({ locationService.authorizationStatus }) {
                guard let self else { return }
                self.locationDenied = (status == .denied || status == .restricted)
            }
        }
    }

    func searchMasjids(near coordinate: CLLocationCoordinate2D) async {
        isLoading = true

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "mosque masjid"
        request.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: searchRadius.rawValue,
            longitudinalMeters: searchRadius.rawValue
        )

        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()

            let userLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let unit = AppSettings.shared.distanceUnit

            masjids = response.mapItems.map { item in
                let distance = item.location.distance(from: userLocation)
                let distanceValue: Double
                let distanceUnit: String
                if unit == .miles {
                    distanceValue = distance / Self.metersPerMile
                    distanceUnit = "mi"
                } else {
                    distanceValue = distance / 1000
                    distanceUnit = "km"
                }

                let itemCoordinate = item.location.coordinate
                let addressString = item.address?.shortAddress ?? item.address?.fullAddress ?? ""

                return MasjidItem(
                    id: UUID(),
                    name: item.name ?? "Unknown Masjid",
                    coordinate: itemCoordinate,
                    address: addressString,
                    distance: distanceValue,
                    distanceUnit: distanceUnit,
                    phoneNumber: item.phoneNumber,
                    url: item.url,
                    mapItem: item
                )
            }
            .sorted { $0.distance < $1.distance }
        } catch {
            logger.error("Masjid search error: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func refreshSearch() {
        guard let location = locationService.currentLocation else { return }
        Task { await searchMasjids(near: location) }
    }

    func openInMaps(_ masjid: MasjidItem) {
        let item = masjid.mapItem ?? MKMapItem(
            location: CLLocation(latitude: masjid.coordinate.latitude, longitude: masjid.coordinate.longitude),
            address: nil
        )
        if masjid.mapItem == nil { item.name = masjid.name }
        item.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
        ])
    }

    /// Opens directions in the Google Maps app when it is installed, otherwise in
    /// Google Maps on the web. `UIApplication.open` reports whether the app could
    /// handle the `comgooglemaps://` URL, so no `LSApplicationQueriesSchemes`
    /// entry (needed only for `canOpenURL`) is required.
    func openInGoogleMaps(_ masjid: MasjidItem) {
        let lat = masjid.coordinate.latitude
        let lng = masjid.coordinate.longitude
        let appURL = URL(string: "comgooglemaps://?daddr=\(lat),\(lng)&directionsmode=driving")
        let webURL = URL(string: "https://www.google.com/maps/dir/?api=1&destination=\(lat),\(lng)")
        Task { @MainActor in
            if let appURL, await UIApplication.shared.open(appURL) { return }
            if let webURL { await UIApplication.shared.open(webURL) }
        }
    }
}

struct MasjidItem: Identifiable {
    let id: UUID
    let name: String
    let coordinate: CLLocationCoordinate2D
    let address: String
    let distance: Double
    let distanceUnit: String
    let phoneNumber: String?
    let url: URL?
    let mapItem: MKMapItem?

    var distanceString: String {
        String(format: "%.1f %@", distance, distanceUnit)
    }
}
