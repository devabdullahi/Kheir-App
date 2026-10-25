import Foundation
import CoreLocation
import SwiftUI

@MainActor
@Observable
final class QiblaViewModel {
    var qiblaBearing: Double = 0
    var compassHeading: Double = 0
    var rotationAngle: Double = 0
    var bearingText: String = ""
    var needsCalibration = false
    var hasLocation = false
    var manualCity: String = ""
    var locationDenied = false

    private let locationService = LocationService.shared
    @ObservationIgnored private var observationTasks: [Task<Void, Never>] = []

    deinit {
        observationTasks.forEach { $0.cancel() }
    }

    func onAppear() {
        locationService.requestPermission()
        locationService.startUpdating()
        locationService.startHeadingUpdates()

        // Each `Observations` sequence emits the current value immediately and
        // then on every change to the observed LocationService property.
        let locationService = locationService
        observationTasks.forEach { $0.cancel() }
        observationTasks = [
            Task { [weak self] in
                for await status in Observations({ locationService.authorizationStatus }) {
                    guard let self else { return }
                    self.locationDenied = (status == .denied || status == .restricted)
                }
            },
            Task { [weak self] in
                for await coordinate in Observations({ locationService.currentLocation }) {
                    guard let coordinate else { continue }
                    guard let self else { return }
                    self.updateBearing(from: coordinate)
                }
            },
            Task { [weak self] in
                for await magneticHeading in Observations({ locationService.magneticHeading }) {
                    guard let magneticHeading else { continue }
                    guard let self else { return }
                    self.compassHeading = magneticHeading
                    self.rotationAngle = self.qiblaBearing - magneticHeading
                }
            },
            Task { [weak self] in
                for await accuracy in Observations({ locationService.headingAccuracy }) {
                    guard let self else { return }
                    self.needsCalibration = accuracy < 0 || accuracy > 25
                }
            }
        ]
    }

    func onDisappear() {
        locationService.stopHeadingUpdates()
        observationTasks.forEach { $0.cancel() }
        observationTasks = []
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
