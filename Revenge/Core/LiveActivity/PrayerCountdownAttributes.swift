import Foundation
import ActivityKit

// MARK: - Prayer countdown Live Activity
//
// IMPORTANT: this file exists twice, byte-for-byte identical:
//   KheirWidget/PrayerCountdownAttributes.swift            (widget extension)
//   Revenge/Core/LiveActivity/PrayerCountdownAttributes.swift (app)
// ActivityKit matches the app's activity to the extension's UI by this type's
// name and Codable shape, so keep both copies in sync when changing it.

struct PrayerCountdownAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable, Sendable {
        /// The prayer being counted down to, e.g. "Maghrib".
        var prayerName: String
        var prayerTime: Date
        /// The prayer before it: the start of the progress strip.
        var previousName: String
        var previousTime: Date
    }

    /// Identifies the prayer instance, e.g. "Maghrib-2026-10-25".
    var prayerID: String
}

extension PrayerCountdownAttributes.ContentState {
    /// 0…1 along the strip from the previous prayer to this one, at `date`.
    func progress(at date: Date) -> Double {
        let total = prayerTime.timeIntervalSince(previousTime)
        guard total > 0 else { return 1 }
        return min(1, max(0, date.timeIntervalSince(previousTime) / total))
    }

    /// A word for the moment of the day, shown under the prayer time.
    var moment: String {
        switch prayerName {
        case "Fajr": "dawn"
        case "Sunrise": "sunrise"
        case "Dhuhr": "midday"
        case "Asr": "afternoon"
        case "Maghrib": "sunset"
        default: "nightfall"
        }
    }
}
