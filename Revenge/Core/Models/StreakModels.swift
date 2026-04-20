import Foundation

// MARK: - StreakData

/// Persisted value representing a user's current app-open streak.
///
/// All date arithmetic uses the "yyyy-MM-dd" key format so comparisons are
/// calendar-day based and independent of clock time — consistent with the
/// `dayKeyFormatter` used in `HomeViewModel`.
struct StreakData: Codable, Equatable {

    /// Number of consecutive days the app has been opened, counting today.
    var currentStreak: Int

    /// The most recent calendar day on which `recordAppOpen()` was called,
    /// stored as a "yyyy-MM-dd" string.
    var lastOpenedDate: String

    /// All-time best streak ever recorded for this user.
    var longestStreak: Int

    // MARK: - Initialisation

    /// Creates a fresh `StreakData` with explicit values.
    init(currentStreak: Int, lastOpenedDate: String, longestStreak: Int) {
        self.currentStreak = currentStreak
        self.lastOpenedDate = lastOpenedDate
        self.longestStreak = longestStreak
    }
}
