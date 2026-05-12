import Foundation
import MapKit
import Combine
import SwiftUI
import os

@MainActor
final class MasjidFinderViewModel: ObservableObject {
    @Published var masjids: [MasjidItem] = []
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 21.4225, longitude: 39.8262),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var isLoading = false
    @Published var searchRadius: SearchRadius = .fiveKm
    @Published var viewMode: ViewMode = .split
    @Published var locationDenied = false

    private let locationService = LocationService.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "MasjidFinder")
    private var cancellables = Set<AnyCancellable>()

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

        locationService.$currentLocation
            .compactMap { $0 }
            .first()
            .sink { [weak self] coordinate in
                self?.region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                Task { await self?.searchMasjids(near: coordinate) }
            }
            .store(in: &cancellables)

        locationService.$authorizationStatus
            .sink { [weak self] status in
                self?.locationDenied = (status == .denied || status == .restricted)
            }
            .store(in: &cancellables)
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
                let distance = item.placemark.location?.distance(from: userLocation) ?? 0
                let distanceValue: Double
                let distanceUnit: String
                if unit == .miles {
                    distanceValue = distance / 1609.34
                    distanceUnit = "mi"
                } else {
                    distanceValue = distance / 1000
                    distanceUnit = "km"
                }

                return MasjidItem(
                    id: UUID(),
                    name: item.name ?? "Unknown Masjid",
                    coordinate: item.placemark.coordinate,
                    address: [item.placemark.thoroughfare, item.placemark.locality, item.placemark.administrativeArea]
                        .compactMap { $0 }.joined(separator: ", "),
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
        masjid.mapItem?.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
        ])
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
