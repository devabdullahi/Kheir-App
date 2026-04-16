import Foundation
import CoreLocation
import Combine
import SwiftUI

@MainActor
final class PrayerTimesViewModel: ObservableObject {
    @Published var prayers: [PrayerTime] = []
    @Published var nextPrayer: PrayerTime?
    @Published var countdownText: String = "--:--"
    @Published var hijriDate: String = ""
    @Published var gregorianDate: String = ""
    @Published var isLoading = false

    private var timer: Timer?
    private let locationService = LocationService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        let today = Date()
        gregorianDate = today.gregorianString
        hijriDate = today.hijriString
    }

    func onAppear() {
        locationService.requestPermission()
        locationService.startUpdating()

        locationService.$currentLocation
            .compactMap { $0 }
            .first()
            .sink { [weak self] coordinate in
                Task { await self?.fetchTimes(coordinate: coordinate) }
            }
            .store(in: &cancellables)

        // Manual city fallback
        if !AppSettings.shared.useAutoLocation && !AppSettings.shared.manualCity.isEmpty {
            Task {
                if let coord = await locationService.geocodeCity(AppSettings.shared.manualCity) {
                    await fetchTimes(coordinate: coord)
                }
            }
        }

        startTimer()
    }

    func onDisappear() {
        timer?.invalidate()
    }

    private func fetchTimes(coordinate: CLLocationCoordinate2D) async {
        isLoading = true
        let settings = AppSettings.shared

        guard let dayTimes = await PrayerTimesService.shared.fetchPrayerTimes(
            coordinate: coordinate,
            method: settings.calculationMethod,
            madhab: settings.madhab
        ) else {
            isLoading = false
            return
        }

        var prayerList = dayTimes.all
        let now = Date()

        // Mark the next prayer
        if let nextIndex = prayerList.firstIndex(where: { $0.time > now }) {
            prayerList[nextIndex] = PrayerTime(
                name: prayerList[nextIndex].name,
                time: prayerList[nextIndex].time,
                icon: prayerList[nextIndex].icon,
                isNext: true
            )
            nextPrayer = prayerList[nextIndex]
        } else {
            // All of today's prayers have passed — roll over to tomorrow's Fajr.
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            if let tomorrowTimes = await PrayerTimesService.shared.fetchPrayerTimes(
                coordinate: coordinate,
                date: tomorrow,
                method: settings.calculationMethod,
                madhab: settings.madhab
            ) {
                let fajr = tomorrowTimes.all.first // DayPrayerTimes.all is ordered Fajr-first
                nextPrayer = fajr.map { PrayerTime(name: $0.name, time: $0.time, icon: $0.icon, isNext: true) }
            }
        }

        prayers = prayerList
        isLoading = false

        // Schedule notifications
        NotificationService.shared.schedulePrayerNotifications(prayers: prayerList, settings: settings)
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let next = self.nextPrayer else { return }
                let remaining = next.time.timeIntervalSince(Date())
                self.countdownText = PrayerCountdownFormatter.format(remaining)
            }
        }
    }
}
