import Foundation
import CoreLocation

@Observable
@MainActor
final class PrayerCountdownViewModel {
    var currentPrayerName: String = ""
    var nextPrayerName: String = ""
    var nextPrayerTime: Date?
    var countdownText: String = "--:--:--"

    private static let locationWaitNanoseconds: UInt64 = 2_000_000_000

    private var timer: Timer?
    private let locationService: LocationService
    private let prayerTimesService: PrayerTimesService
    private let settings: AppSettings

    init(
        locationService: LocationService = .shared,
        prayerTimesService: PrayerTimesService = .shared,
        settings: AppSettings = .shared
    ) {
        self.locationService = locationService
        self.prayerTimesService = prayerTimesService
        self.settings = settings
    }

    func onAppear() {
        loadPrayerCountdown()
        startCountdownTimer()
    }

    func onDisappear() {
        timer?.invalidate()
        timer = nil
    }

    private func loadPrayerCountdown() {
        guard let location = locationService.currentLocation else {
            Task {
                try? await Task.sleep(nanoseconds: Self.locationWaitNanoseconds)
                guard !Task.isCancelled else { return }
                if let loc = locationService.currentLocation {
                    await updateNextPrayer(location: loc)
                }
            }
            return
        }
        Task {
            await updateNextPrayer(location: location)
        }
    }

    private func updateNextPrayer(location: CLLocationCoordinate2D) async {
        guard let times = await prayerTimesService.fetchPrayerTimes(
            coordinate: location,
            method: settings.calculationMethod,
            madhab: settings.madhab
        ) else { return }

        let now = Date()
        let allTimes = times.all
        if let nextIndex = allTimes.firstIndex(where: { $0.time > now }) {
            nextPrayerName = allTimes[nextIndex].name
            nextPrayerTime = allTimes[nextIndex].time
            // Current prayer is the one before next, or Isha if next is Fajr
            if nextIndex > 0 {
                currentPrayerName = allTimes[nextIndex - 1].name
            } else {
                currentPrayerName = "Isha"
            }
        } else {
            // All prayers passed — currently in Isha, next is tomorrow's Fajr
            currentPrayerName = "Isha"
            nextPrayerName = "Fajr"
            if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: times.fajr) {
                nextPrayerTime = nextDay
            }
        }
    }

    private func startCountdownTimer() {
        timer?.invalidate()
        let newTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, let target = self.nextPrayerTime else { return }
                self.countdownText = Date().timeRemaining(to: target)
                if target <= Date() {
                    self.loadPrayerCountdown()
                }
            }
        }
        RunLoop.main.add(newTimer, forMode: .common)
        timer = newTimer
    }
}
