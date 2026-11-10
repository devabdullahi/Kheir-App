import Foundation

// MARK: - Shared prayer schedule (widget side)
//
// The app writes upcoming prayer times to the App Group as JSON (see
// `Kheir/Core/LiveActivity/SharedPrayerSchedule.swift`, which must stay
// byte-compatible with this file). Format, key `widget_prayer_schedule_v1`:
//
//   { "generatedAt": 1761400000, "prayers": [ { "name": "Fajr", "time": 1761369480 }, … ] }
//
// Times are seconds since 1970. Names are Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha.

struct WidgetPrayer: Codable, Hashable, Sendable {
    let name: String
    let time: Double

    var date: Date { Date(timeIntervalSince1970: time) }
}

struct WidgetPrayerSchedule: Codable, Sendable {
    let generatedAt: Double
    let prayers: [WidgetPrayer]

    static let appGroupID = "group.com.kheir.shared"
    static let defaultsKey = "widget_prayer_schedule_v1"
    static let fivePrayers: Set<String> = ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

    static func load() -> WidgetPrayerSchedule? {
        guard let data = UserDefaults(suiteName: appGroupID)?.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(WidgetPrayerSchedule.self, from: data)
    }

    /// The five daily prayers (no Sunrise), sorted by time.
    var obligatory: [WidgetPrayer] {
        prayers.filter { Self.fivePrayers.contains($0.name) }.sorted { $0.time < $1.time }
    }

    /// The five prayers of the calendar day containing `day`.
    func prayers(onDayOf day: Date, calendar: Calendar = .current) -> [WidgetPrayer] {
        obligatory.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }
}
