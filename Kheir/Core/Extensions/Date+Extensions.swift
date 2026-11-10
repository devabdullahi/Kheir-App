import Foundation

extension Date {

    // MARK: - Cached Formatters

    private static let gregorianFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()

    private static let hijriFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .islamicUmmAlQura)
        f.dateFormat = "d MMMM yyyy"
        f.locale = Locale(identifier: "en")
        return f
    }()

    /// Formatter for `dayKey` — no explicit timezone, so it follows the device locale.
    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Formatter for `currentDayKey()` — explicitly pinned to the device-local timezone
    /// so widget and app targets produce identical keys regardless of any default overrides.
    private static let currentDayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    // MARK: - Computed Properties

    var gregorianString: String {
        Self.gregorianFormatter.string(from: self)
    }

    var hijriString: String {
        Self.hijriFormatter.string(from: self) + " AH"
    }

    var dayKey: String {
        Self.dayKeyFormatter.string(from: self)
    }

    /// Returns today's cache key (`yyyy-MM-dd`) using the device-local timezone.
    /// Public so the KheirWidget extension target can call it without duplicating
    /// the formatter. Add `Date+Extensions.swift` to the widget target membership.
    static func currentDayKey() -> String {
        Self.currentDayKeyFormatter.string(from: Date())
    }

    var timeString: String {
        Self.timeFormatter.string(from: self)
    }

    // MARK: - Helpers

    func timeRemaining(to target: Date) -> String {
        let interval = target.timeIntervalSince(self)
        guard interval > 0 else { return "Now" }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        if hours > 0 {
            return String(format: "%dh %02dm %02ds", hours, minutes, seconds)
        } else {
            return String(format: "%dm %02ds", minutes, seconds)
        }
    }

    static func fromTimeString(_ timeStr: String, on date: Date = Date()) -> Date? {
        let parts = timeStr.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count >= 2,
              let hour = Int(parts[0]),
              let minute = Int(String(parts[1]).prefix(2)) else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = .current
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)
    }
}
