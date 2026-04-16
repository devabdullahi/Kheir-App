import Foundation
import CoreLocation
import Combine
import SwiftUI

@MainActor
final class QiblaViewModel: ObservableObject {
    @Published var qiblaBearing: Double = 0
    @Published var compassHeading: Double = 0
    @Published var rotationAngle: Double = 0
    @Published var bearingText: String = ""
    @Published var needsCalibration = false
    @Published var hasLocation = false
    @Published var manualCity: String = ""
    @Published var locationDenied = false

    private let locationService = LocationService.shared
    private var cancellables = Set<AnyCancellable>()

    func onAppear() {
        locationService.requestPermission()
        locationService.startUpdating()
        locationService.startHeadingUpdates()

        locationService.$authorizationStatus
            .sink { [weak self] status in
                self?.locationDenied = (status == .denied || status == .restricted)
            }
            .store(in: &cancellables)

        locationService.$currentLocation
            .compactMap { $0 }
            .sink { [weak self] coordinate in
                self?.updateBearing(from: coordinate)
            }
            .store(in: &cancellables)

        locationService.$heading
            .compactMap { $0 }
            .sink { [weak self] heading in
                guard let self = self else { return }
                self.compassHeading = heading.magneticHeading
                self.rotationAngle = self.qiblaBearing - heading.magneticHeading
            }
            .store(in: &cancellables)

        locationService.$headingAccuracy
            .sink { [weak self] accuracy in
                self?.needsCalibration = accuracy < 0 || accuracy > 25
            }
            .store(in: &cancellables)
    }

    func onDisappear() {
        locationService.stopHeadingUpdates()
    }

    private func updateBearing(from coordinate: CLLocationCoordinate2D) {
        hasLocation = true
        qiblaBearing = QiblaService.bearing(from: coordinate)
        let cardinal = QiblaService.cardinalDirection(for: qiblaBearing)
        bearingText = String(format: "%.0f° %@", qiblaBearing, cardinal)
        rotationAngle = qiblaBearing - compassHeading
    }

    func searchCity() {
        Task {
            if let coord = await locationService.geocodeCity(manualCity) {
                updateBearing(from: coord)
            }
        }
    }
}
