import Foundation
import UserNotifications
import CoreLocation
import os

final class NotificationService: Sendable {
    static let shared = NotificationService()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "NotificationService")
    private init() {}

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Notification permission error: \(error.localizedDescription)")
            return false
        }
    }

    @MainActor
    func schedulePrayerNotifications(prayers: [PrayerTime], settings: AppSettings) {
        let center = UNUserNotificationCenter.current()

        // Remove old prayer notifications
        center.removePendingNotificationRequests(withIdentifiers:
            prayers.map { "prayer_\($0.name)" }
        )

        let enabledPrayers = enabledPrayerNames(
            fajr: settings.fajrNotification, sunrise: settings.sunriseNotification,
            dhuhr: settings.dhuhrNotification, asr: settings.asrNotification,
            maghrib: settings.maghribNotification, isha: settings.ishaNotification
        )

        for prayer in prayers {
            guard enabledPrayers.contains(prayer.name),
                  prayer.time > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(prayer.name) Prayer"
            content.body = "It's time for \(prayer.name) prayer (\(prayer.timeString))"
            content.sound = .default
            content.categoryIdentifier = "PRAYER_TIME"

            let components = Calendar.current.dateComponents([.hour, .minute], from: prayer.time)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let request = UNNotificationRequest(
                identifier: "prayer_\(prayer.name)",
                content: content,
                trigger: trigger
            )

            center.add(request) { error in
                if let error = error {
                    self.logger.error("Failed to schedule \(prayer.name): \(error.localizedDescription)")
                }
            }
        }
    }

    @MainActor
    func scheduleWeekOfNotifications(coordinate: (Double, Double), settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let loc = CoreLocation.CLLocationCoordinate2D(latitude: coordinate.0, longitude: coordinate.1)
        let calendar = Calendar.current

        for dayOffset in 0..<AppConstants.notificationDaysAhead {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()),
                  let prayerTimes = await PrayerTimesService.shared.fetchPrayerTimes(
                    coordinate: loc,
                    date: date,
                    method: settings.calculationMethod,
                    madhab: settings.madhab
                  ) else { continue }

            let enabled = enabledPrayerNames(
                fajr: settings.fajrNotification, sunrise: settings.sunriseNotification,
                dhuhr: settings.dhuhrNotification, asr: settings.asrNotification,
                maghrib: settings.maghribNotification, isha: settings.ishaNotification
            )
            for prayer in prayerTimes.all where enabled.contains(prayer.name) && prayer.time > Date() {
                let content = UNMutableNotificationContent()
                content.title = "\(prayer.name) Prayer"
                content.body = "It's time for \(prayer.name) prayer (\(prayer.timeString))"
                content.sound = .default

                let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: prayer.time)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let id = "prayer_\(prayer.name)_\(date.dayKey)"
                let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }


    func sendTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Kheir — Test"
        content.body = "Prayer reminders are working"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(
            identifier: "kheir_test_notification",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                self.logger.error("Test notification error: \(error.localizedDescription)")
            }
        }
    }

    private func enabledPrayerNames(
        fajr: Bool, sunrise: Bool, dhuhr: Bool,
        asr: Bool, maghrib: Bool, isha: Bool
    ) -> Set<String> {
        var names: Set<String> = []
        if fajr { names.insert("Fajr") }
        if sunrise { names.insert("Sunrise") }
        if dhuhr { names.insert("Dhuhr") }
        if asr { names.insert("Asr") }
        if maghrib { names.insert("Maghrib") }
        if isha { names.insert("Isha") }
        return names
    }
}
