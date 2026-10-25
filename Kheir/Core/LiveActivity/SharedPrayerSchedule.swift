import Foundation
import WidgetKit

// MARK: - Shared prayer schedule (app side)
//
// Writes upcoming prayer times to the App Group so the Next Prayer widget and the
// Live Activity manager can read them without recalculating. The JSON format must
// stay compatible with `KheirWidget/PrayerSchedule.swift`:
//
//   key `widget_prayer_schedule_v1` →
//   { "generatedAt": <unix seconds>, "prayers": [ { "name": "Fajr", "time": <unix seconds> }, … ] }
//
// `NotificationService` calls `write(_:)` every time it (re)schedules prayer
// notifications, so nothing else needs to call this.

struct SharedPrayer: Codable, Hashable, Sendable {
    let name: String
    let time: Double

    var date: Date { Date(timeIntervalSince1970: time) }
}

struct SharedPrayerSchedule: Codable, Sendable {
    let generatedAt: Double
    let prayers: [SharedPrayer]

    static let appGroupID = "group.com.kheir.shared"
    static let defaultsKey = "widget_prayer_schedule_v1"
    static let widgetKind = "NextPrayerWidget"
    static let fivePrayers: Set<String> = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

    /// Stores upcoming prayer times (today, tomorrow, …) and reloads the widget.
    /// Pass every `PrayerTime` you have; days before today are dropped and only
    /// today plus the next two days are kept.
    static func write(_ times: [PrayerTime]) {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        let horizon = calendar.date(byAdding: .day, value: 3, to: startOfToday) ?? startOfToday.addingTimeInterval(3 * 86400)
        let prayers = times
            .filter { $0.time < horizon }
            .filter { $0.time >= startOfToday }
            .sorted { $0.time < $1.time }
            .map { SharedPrayer(name: $0.name, time: $0.time.timeIntervalSince1970) }
        guard !prayers.isEmpty else { return }

        // Merge with what is already stored so a today-only write does not wipe tomorrow.
        let existing = load()?.prayers ?? []
        var merged: [String: SharedPrayer] = [:]
        for p in existing where p.date >= startOfToday {
            merged[key(for: p)] = p
        }
        for p in prayers { merged[key(for: p)] = p }
        let sorted = merged.values.sorted { $0.time < $1.time }
        if sorted == existing { return }   // nothing changed: skip the widget reload

        let schedule = SharedPrayerSchedule(generatedAt: Date().timeIntervalSince1970, prayers: sorted)
        guard let data = try? JSONEncoder().encode(schedule),
              let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(data, forKey: defaultsKey)
        WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
    }

    static func load() -> SharedPrayerSchedule? {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(SharedPrayerSchedule.self, from: data)
    }

    private static func key(for p: SharedPrayer) -> String {
        "\(p.name)-\(Date(timeIntervalSince1970: p.time).dayKey)"
    }
}
