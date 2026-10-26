import Foundation

/// Pure, stateless formatter for countdown-to-prayer display.
///
/// Produces `HH:MM:SS` strings suitable for the prayer-times countdown UI.
/// Extracted from `PrayerTimesViewModel` so the formatting rule can be tested
/// independently of `@MainActor` / `@Published` state.
enum PrayerCountdownFormatter {

    /// Formats a non-negative `TimeInterval` as `"HH:MM:SS"`.
    ///
    /// - Parameter interval: Seconds remaining until the next prayer.
    ///   Values ≤ 0 return `"00:00:00"`.
    /// - Returns: Zero-padded string in the form `"HH:MM:SS"`.
    static func format(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        let hours   = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}
