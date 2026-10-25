import Foundation
import CoreLocation
import SwiftUI
import os

@MainActor
@Observable
final class PrayerTimesViewModel {
    var prayers: [PrayerTime] = []
    var nextPrayer: PrayerTime?
    var countdownText: String = "--:--"
    var hijriDate: String = ""
    var gregorianDate: String = ""
    var isLoading = false
    var hasAttemptedLoad = false
    var statusMessage: String = ""

    private var countdownTask: Task<Void, Never>?
    private let locationService: LocationService
    private let prayerTimesService: PrayerTimesService
    private let notificationService: NotificationService
    private let settings: AppSettings
    @ObservationIgnored private var firstLocationTask: Task<Void, Never>?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "PrayerTimesViewModel")

    init(
        locationService: LocationService? = nil,
        prayerTimesService: PrayerTimesService? = nil,
        notificationService: NotificationService? = nil,
        settings: AppSettings? = nil
    ) {
        self.locationService = locationService ?? .shared
        self.prayerTimesService = prayerTimesService ?? .shared
        self.notificationService = notificationService ?? .shared
        self.settings = settings ?? .shared
        let today = Date()
        gregorianDate = today.gregorianString
        hijriDate = today.hijriString
    }

    func onAppear() {
        logger.debug("onAppear: useAutoLocation=\(self.settings.useAutoLocation), manualCity=\(self.settings.manualCity)")
        locationService.requestPermission()
        locationService.startUpdating()
        logger.debug("Requested permission and started updating location")

        // React to only the first non-nil GPS fix to avoid repeated refetches.
        // `Observations` emits the current value immediately, then on change.
        let locationService = locationService
        firstLocationTask?.cancel()
        firstLocationTask = Task { [weak self] in
            for await coordinate in Observations({ locationService.currentLocation }) {
                guard let coordinate else { continue }
                guard let self else { return }
                self.logger.debug("Received first location update: \(coordinate.latitude), \(coordinate.longitude)")
                await self.fetchTimes(coordinate: coordinate)
                return
            }
        }

        // If a coordinate already exists in memory or on disk (last-known),
        // use it immediately so the UI doesn't sit empty while waiting for
        // a fresh GPS fix — particularly important on the simulator and on
        // first launch before any permission decision.
        if prayers.isEmpty, let cached = locationService.lastKnownLocation ?? locationService.currentLocation {
            logger.debug("Using cached/last-known location: \(cached.latitude), \(cached.longitude)")
            Task { await fetchTimes(coordinate: cached) }
        }

        // Timeout fallback: if the network is slow or permission was denied,
        // fall back to manual city, then a previously-cached coordinate,
        // and finally surface a status message instead of leaving the screen blank.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self = self else { return }
            self.logger.debug("Timeout fallback triggered. prayers.isEmpty=\(self.prayers.isEmpty)")
            if self.prayers.isEmpty {
                if !self.settings.manualCity.isEmpty {
                    self.logger.debug("Timeout fallback using manual city: \(self.settings.manualCity)")
                    if let coord = await self.locationService.geocodeCity(self.settings.manualCity) {
                        await self.fetchTimes(coordinate: coord, force: true)
                        if self.prayers.isEmpty {
                            await MainActor.run {
                                self.isLoading = false
                                self.hasAttemptedLoad = true
                                self.statusMessage = "Could not load times for \(self.settings.manualCity)."
                            }
                        }
                    } else {
                        await MainActor.run {
                            self.isLoading = false
                            self.hasAttemptedLoad = true
                            self.statusMessage = "Could not find city: \(self.settings.manualCity)"
                        }
                    }
                } else if let coord = self.locationService.lastKnownLocation {
                    self.logger.debug("Timeout fallback using last-known location: \(coord.latitude), \(coord.longitude)")
                    await self.fetchTimes(coordinate: coord, force: true)
                    if self.prayers.isEmpty {
                        await MainActor.run {
                            self.isLoading = false
                            self.hasAttemptedLoad = true
                        }
                    }
                } else {
                    await MainActor.run {
                        self.isLoading = false
                        self.hasAttemptedLoad = true
                        self.statusMessage = "No location available. Enable location or set a manual city in Settings."
                    }
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                    self.hasAttemptedLoad = true
                }
            }
        }

        // Manual city (when auto-location is intentionally off)
        if !settings.useAutoLocation && !settings.manualCity.isEmpty {
            logger.debug("Manual city fallback: \(self.settings.manualCity)")
            Task {
                if let coord = await locationService.geocodeCity(settings.manualCity) {
                    await fetchTimes(coordinate: coord)
                    await MainActor.run {
                        self.locationService.setLocation(coord) // remember for next launch
                    }
                }
            }
        }

        startTimer()
    }

    func onDisappear() {
        countdownTask?.cancel()
        countdownTask = nil
        firstLocationTask?.cancel()
        firstLocationTask = nil
    }

    func retry() {
        logger.debug("Retry requested")
        isLoading = false  // Reset so fetchTimes can proceed
        statusMessage = ""
        Task { [weak self] in
            guard let self = self else { return }
            if !self.settings.manualCity.isEmpty {
                self.logger.debug("Retry using manual city: \(self.settings.manualCity)")
                if let coord = await self.locationService.geocodeCity(self.settings.manualCity) {
                    self.locationService.setLocation(coord)
                    await self.fetchTimes(coordinate: coord, force: true)
                } else {
                    await MainActor.run { self.statusMessage = "Could not find city: \(self.settings.manualCity)" }
                }
            } else if let coord = self.locationService.lastKnownLocation ?? self.locationService.currentLocation {
                self.logger.debug("Retry using last-known/current location: \(coord.latitude), \(coord.longitude)")
                await self.fetchTimes(coordinate: coord, force: true)
            } else {
                await MainActor.run { self.statusMessage = "No location available. Please enable location or set a manual city." }
            }
        }
    }

    private func fetchTimes(coordinate: CLLocationCoordinate2D, force: Bool = false) async {
        logger.debug("Fetching times for: \(coordinate.latitude), \(coordinate.longitude), force=\(force)")
        statusMessage = ""
        if isLoading && !force { return }
        isLoading = true

        guard let dayTimes = await prayerTimesService.fetchPrayerTimes(
            coordinate: coordinate,
            method: settings.calculationMethod,
            madhab: settings.madhab
        ) else {
            prayers = []
            nextPrayer = nil
            isLoading = false
            hasAttemptedLoad = true
            statusMessage = "Unable to load prayer times. Check network or settings."
            logger.error("fetchPrayerTimes returned nil")
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
            if let tomorrowTimes = await prayerTimesService.fetchPrayerTimes(
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
        hasAttemptedLoad = true
        statusMessage = prayerList.isEmpty ? "No prayer times for today." : ""
        logger.debug("Loaded \(prayerList.count) prayers. Next: \(self.nextPrayer?.name ?? "-")")

        // Schedule notifications
        notificationService.schedulePrayerNotifications(prayers: prayerList, settings: settings)

        // Update countdown immediately
        if let next = nextPrayer {
            countdownText = PrayerCountdownFormatter.format(next.time.timeIntervalSince(Date()))
        }
    }

    private func startTimer() {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                if let next = self.nextPrayer {
                    await MainActor.run {
                        let remaining = next.time.timeIntervalSince(Date())
                        self.countdownText = PrayerCountdownFormatter.format(remaining)
                    }
                }
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }
}
