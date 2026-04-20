import Foundation

// MARK: - StreakService

/// Tracks the user's consecutive-day app-open streak.
///
/// Design decisions:
///   - `calendar` and `cache` are injected at init so unit tests can supply a
///     fixed `Calendar` (with a known `timeZone`) and an in-memory `MockCacheManager`
///     without touching the file system.
///   - All date arithmetic uses `Calendar.dateComponents` as required — no
///     `timeIntervalSince` arithmetic that breaks across DST boundaries.
///   - The service is deliberately free of `@MainActor` because streak computation
///     is pure value logic that does not drive UI directly. ViewModels calling
///     `recordAppOpen()` may dispatch to the main actor themselves.
///   - No force unwraps: every optional is handled with `guard` / `if let`.
final class StreakService {

    // MARK: - Shared Instance

    /// The singleton used by production code.
    static let shared = StreakService()

    // MARK: - Private State

    /// Calendar used for all day-difference calculations. Injected for testability.
    private let calendar: Calendar

    /// Persistence layer. Injected for testability.
    private let cache: any CacheManaging

    /// Formatter that converts `Date` → "yyyy-MM-dd". Matches `HomeViewModel.dayKeyFormatter`.
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // MARK: - Initialisation

    /// Production initialiser — uses the device calendar and the shared `CacheManager`.
    private convenience init() {
        self.init(calendar: .current, cache: CacheManager.shared)
    }

    /// Designated initialiser for dependency injection (tests).
    ///
    /// - Parameters:
    ///   - calendar: The `Calendar` used for day-difference calculations.
    ///     Pass a calendar with a fixed `timeZone` in tests to avoid DST surprises.
    ///   - cache: The persistence layer to read from and write to.
    init(calendar: Calendar, cache: any CacheManaging) {
        self.calendar = calendar
        self.cache = cache
        // Propagate the calendar's time zone to the formatter so date keys are
        // computed in the same zone as the day-arithmetic — critical for the
        // 23:59 → 00:01 edge case in tests.
        dateFormatter.timeZone = calendar.timeZone
    }

    // MARK: - Date Key Helpers

    /// Returns the "yyyy-MM-dd" key for `date` in the service's calendar time zone.
    private func dateKey(for date: Date) -> String {
        dateFormatter.string(from: date)
    }

    /// Parses a "yyyy-MM-dd" string back into a `Date` at midnight in the service's
    /// calendar time zone. Returns `nil` if the string is malformed.
    private func date(from key: String) -> Date? {
        dateFormatter.date(from: key)
    }

    /// Returns the number of calendar days between `fromKey` and `toKey`.
    /// Both keys must be "yyyy-MM-dd" strings. Returns `nil` when either key
    /// cannot be parsed or when `DateComponents.day` is unavailable.
    private func daysBetween(from fromKey: String, to toKey: String) -> Int? {
        guard
            let fromDate = date(from: fromKey),
            let toDate = date(from: toKey)
        else { return nil }

        let components = calendar.dateComponents([.day], from: fromDate, to: toDate)
        return components.day
    }
}

// MARK: - StreakTracking

extension StreakService {

    /// Records that the app was opened today and returns the updated `StreakData`.
    ///
    /// Rules (evaluated in order):
    /// 1. If `lastOpenedDate == today` → no change, return existing data unchanged.
    /// 2. If `days == 1` since last open → consecutive day, increment streak.
    /// 3. If `days > 1` since last open → gap detected, reset streak to 1.
    /// 4. If no prior data exists → first ever open, set streak to 1.
    ///
    /// After computing the new streak, `longestStreak` is updated if the current
    /// value exceeds the stored all-time best. The result is persisted and returned.
    @discardableResult
    func recordAppOpen() -> StreakData {
        let todayKey = dateKey(for: Date())

        // Load existing data — may be nil on first launch.
        if var existing = cache.loadStreak() {
            // Rule 1: already recorded today, nothing to do.
            if existing.lastOpenedDate == todayKey {
                return existing
            }

            // Compute calendar-day distance using dateComponents (not timeIntervalSince).
            let days = daysBetween(from: existing.lastOpenedDate, to: todayKey)

            if days == 1 {
                // Rule 2: consecutive day.
                existing.currentStreak += 1
            } else {
                // Rule 3: gap — streak resets. The user did open today, so streak = 1.
                existing.currentStreak = 1
            }

            existing.lastOpenedDate = todayKey

            // Update all-time best if needed.
            if existing.currentStreak > existing.longestStreak {
                existing.longestStreak = existing.currentStreak
            }

            cache.saveStreak(existing)
            return existing
        } else {
            // Rule 4: first ever open.
            let fresh = StreakData(currentStreak: 1, lastOpenedDate: todayKey, longestStreak: 1)
            cache.saveStreak(fresh)
            return fresh
        }
    }

    /// Returns the currently persisted `StreakData`, or `nil` if the user has never
    /// triggered `recordAppOpen()`.
    func loadStreak() -> StreakData? {
        cache.loadStreak()
    }

    /// Wipes the persisted streak. Subsequent calls to `recordAppOpen()` will treat
    /// the next open as a first-ever open (streak resets to 1).
    ///
    /// Implementation note: `CacheManaging` does not expose a generic `delete` method,
    /// so we persist a zeroed sentinel (`currentStreak == 0`, `lastOpenedDate == ""`).
    /// `recordAppOpen()` detects the empty date string — `daysBetween` returns `nil`
    /// because the empty string cannot be parsed — causing the streak to reset to 1 on
    /// the next launch. `loadStreak()` returns this zeroed struct; callers should treat
    /// `currentStreak == 0` as "no streak established yet".
    func resetStreak() {
        let zeroed = StreakData(currentStreak: 0, lastOpenedDate: "", longestStreak: 0)
        cache.saveStreak(zeroed)
    }
}
