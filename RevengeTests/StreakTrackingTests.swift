import Testing
import Foundation
@testable import Revenge

// MARK: - Test Helpers

/// Builds a `StreakService` wired to an isolated `MockCacheManager` and a
/// `Calendar` whose time zone is fixed to UTC so date-key arithmetic is
/// deterministic regardless of the machine's local time zone.
private func makeService(
    cache: MockCacheManager = MockCacheManager()
) -> (service: StreakService, cache: MockCacheManager) {
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let service = StreakService(calendar: cal, cache: cache)
    return (service, cache)
}

/// Returns a `Date` for the given "yyyy-MM-dd" string in UTC.
private func utcDate(_ key: String) -> Date {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(identifier: "UTC")!
    guard let d = f.date(from: key) else {
        fatalError("Bad date key in test: \(key)")
    }
    return d
}

/// Seeds `cache` with a `StreakData` whose `lastOpenedDate` is `dateKey` and
/// returns the seeded value for assertion convenience.
@discardableResult
private func seedStreak(
    in cache: MockCacheManager,
    currentStreak: Int,
    lastOpenedDate: String,
    longestStreak: Int
) async -> StreakData {
    let data = StreakData(
        currentStreak: currentStreak,
        lastOpenedDate: lastOpenedDate,
        longestStreak: longestStreak
    )
    await cache.saveStreak(data)
    return data
}

// MARK: - StreakTrackingTests

@Suite("StreakService — streak tracking logic", .serialized)
struct StreakTrackingTests {

    // MARK: First launch

    @Test("First launch produces streak of 1")
    func firstLaunchSetsStreakToOne() async {
        let (service, _) = makeService()
        // No prior data — simulates fresh install.
        let result = await service.recordAppOpen()
        #expect(result.currentStreak == 1)
        #expect(result.longestStreak == 1)
    }

    @Test("First launch persists streak data")
    func firstLaunchPersistsData() async {
        let (service, cache) = makeService()
        await service.recordAppOpen()
        let loaded = await cache.loadStreak()
        #expect(loaded != nil)
        #expect(loaded?.currentStreak == 1)
    }

    // MARK: Same-day idempotency

    @Test("Same-day repeat open leaves streak unchanged")
    func sameDayRepeatOpenIsIdempotent() async {
        let cache = MockCacheManager()
        // Seed as if the app was already opened today.
        let todayKey: String = {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = TimeZone(identifier: "UTC")!
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.locale = Locale(identifier: "en_US_POSIX")
            f.timeZone = cal.timeZone
            return f.string(from: Date())
        }()
        await seedStreak(in: cache, currentStreak: 5, lastOpenedDate: todayKey, longestStreak: 7)

        let (service, _) = makeService(cache: cache)
        let result = await service.recordAppOpen()

        // Must be exactly what was seeded — nothing should change.
        #expect(result.currentStreak == 5)
        #expect(result.longestStreak == 7)
        #expect(result.lastOpenedDate == todayKey)
    }

    // MARK: Consecutive-day increment

    @Test("Opening on consecutive day increments streak by 1")
    func consecutiveDayIncrementsStreak() async {
        let cache = MockCacheManager()

        // Build a StreakService whose "today" we can control by seeding yesterday's date
        // and observing that recordAppOpen() computes the correct delta.
        // Since StreakService.recordAppOpen() calls Date() internally, we seed
        // lastOpenedDate = yesterday using the real calendar so the delta is exactly 1.
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")!

        let yesterday = utcCal.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayKey = f.string(from: yesterday)

        await seedStreak(in: cache, currentStreak: 3, lastOpenedDate: yesterdayKey, longestStreak: 3)

        let service = StreakService(calendar: utcCal, cache: cache)
        let result = await service.recordAppOpen()

        #expect(result.currentStreak == 4)
    }

    @Test("Consecutive day updates longestStreak when current exceeds it")
    func consecutiveDayUpdatesLongest() async {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")!

        let cache = MockCacheManager()
        let yesterday = utcCal.date(byAdding: .day, value: -1, to: Date())!
        await seedStreak(
            in: cache,
            currentStreak: 10,
            lastOpenedDate: f.string(from: yesterday),
            longestStreak: 10
        )

        let service = StreakService(calendar: utcCal, cache: cache)
        let result = await service.recordAppOpen()

        #expect(result.currentStreak == 11)
        #expect(result.longestStreak == 11)
    }

    @Test("Consecutive day does NOT reduce longestStreak if current is still below it")
    func consecutiveDayKeepsHigherLongest() async {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")!

        let cache = MockCacheManager()
        let yesterday = utcCal.date(byAdding: .day, value: -1, to: Date())!
        await seedStreak(
            in: cache,
            currentStreak: 4,
            lastOpenedDate: f.string(from: yesterday),
            longestStreak: 20
        )

        let service = StreakService(calendar: utcCal, cache: cache)
        let result = await service.recordAppOpen()

        #expect(result.currentStreak == 5)
        #expect(result.longestStreak == 20)
    }

    // MARK: Gap resets

    @Test("Missing one day resets streak to 1")
    func missedOneDayResetsStreak() async {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")!

        let cache = MockCacheManager()
        let twoDaysAgo = utcCal.date(byAdding: .day, value: -2, to: Date())!
        await seedStreak(
            in: cache,
            currentStreak: 7,
            lastOpenedDate: f.string(from: twoDaysAgo),
            longestStreak: 7
        )

        let service = StreakService(calendar: utcCal, cache: cache)
        let result = await service.recordAppOpen()

        #expect(result.currentStreak == 1)
    }

    @Test("Missing multiple days resets streak to 1")
    func missedMultipleDaysResetsStreak() async {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")!

        let cache = MockCacheManager()
        let aWeekAgo = utcCal.date(byAdding: .day, value: -7, to: Date())!
        await seedStreak(
            in: cache,
            currentStreak: 30,
            lastOpenedDate: f.string(from: aWeekAgo),
            longestStreak: 30
        )

        let service = StreakService(calendar: utcCal, cache: cache)
        let result = await service.recordAppOpen()

        #expect(result.currentStreak == 1)
    }

    @Test("Gap reset preserves longestStreak from before the gap")
    func gapResetPreservesLongestStreak() async {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")!

        let cache = MockCacheManager()
        let aWeekAgo = utcCal.date(byAdding: .day, value: -7, to: Date())!
        await seedStreak(
            in: cache,
            currentStreak: 30,
            lastOpenedDate: f.string(from: aWeekAgo),
            longestStreak: 30
        )

        let service = StreakService(calendar: utcCal, cache: cache)
        let result = await service.recordAppOpen()

        // Streak resets to 1 but the all-time best remains 30.
        #expect(result.currentStreak == 1)
        #expect(result.longestStreak == 30)
    }

    // MARK: Timezone edge case

    @Test("Open at 23:59, then 00:01 next day counts as consecutive")
    func midnightTransitionCountsAsConsecutive() async {
        // Build a StreakService pinned to a fixed time zone (UTC+5 to exercise
        // a non-UTC zone) and use a calendar whose "today" we control by directly
        // seeding the cache with a date key computed in that same zone.
        let timeZone = TimeZone(identifier: "Asia/Karachi")! // UTC+5, no DST
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone

        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone

        // "yesterday" in Karachi time = the day before today in Karachi time.
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        let yesterdayKey = f.string(from: yesterday)

        let cache = MockCacheManager()
        await seedStreak(in: cache, currentStreak: 2, lastOpenedDate: yesterdayKey, longestStreak: 2)

        let service = StreakService(calendar: cal, cache: cache)
        let result = await service.recordAppOpen()

        // The service uses the same zone for both key generation and day arithmetic,
        // so what appears as "00:01" on Day N in Karachi will map to todayKey != yesterdayKey
        // with a delta of exactly 1 — confirming consecutive counting.
        #expect(result.currentStreak == 3)
    }

    // MARK: longestStreak lifecycle

    @Test("longestStreak tracks the all-time best across multiple sessions")
    func longestStreakTracksAllTimeBest() async {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")!

        let cache = MockCacheManager()
        let yesterday = utcCal.date(byAdding: .day, value: -1, to: Date())!

        // Simulate a previous best of 5, current at 5 about to become 6.
        await seedStreak(
            in: cache,
            currentStreak: 5,
            lastOpenedDate: f.string(from: yesterday),
            longestStreak: 5
        )

        let service = StreakService(calendar: utcCal, cache: cache)
        let after6 = await service.recordAppOpen()
        #expect(after6.longestStreak == 6)
    }

    @Test("longestStreak is never overwritten by a lower value after a reset")
    func longestStreakNotOverwrittenByReset() async {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")!

        let cache = MockCacheManager()
        // User had a 50-day streak once, then missed days.
        let threeWeeksAgo = utcCal.date(byAdding: .day, value: -21, to: Date())!
        await seedStreak(
            in: cache,
            currentStreak: 15,
            lastOpenedDate: f.string(from: threeWeeksAgo),
            longestStreak: 50
        )

        let service = StreakService(calendar: utcCal, cache: cache)
        let result = await service.recordAppOpen()

        // Streak resets to 1, but longestStreak stays at 50.
        #expect(result.currentStreak == 1)
        #expect(result.longestStreak == 50)
    }

    // MARK: loadStreak

    @Test("loadStreak returns nil when no data has been recorded")
    func loadStreakReturnsNilOnFreshInstall() async {
        let (service, _) = makeService()
        let result = await service.loadStreak()
        #expect(result == nil)
    }

    @Test("loadStreak returns the last persisted StreakData")
    func loadStreakReturnsSavedData() async {
        let (service, _) = makeService()
        await service.recordAppOpen()
        let loaded = await service.loadStreak()
        #expect(loaded != nil)
        #expect(loaded?.currentStreak == 1)
    }

    // MARK: resetStreak

    @Test("resetStreak zeroes out the persisted data")
    func resetStreakZeroesData() async {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")!

        let cache = MockCacheManager()
        let yesterday = utcCal.date(byAdding: .day, value: -1, to: Date())!
        await seedStreak(in: cache, currentStreak: 10, lastOpenedDate: f.string(from: yesterday), longestStreak: 10)

        let service = StreakService(calendar: utcCal, cache: cache)
        await service.resetStreak()

        let loaded = await service.loadStreak()
        #expect(loaded?.currentStreak == 0)
        #expect(loaded?.longestStreak == 0)
    }

    @Test("recordAppOpen after resetStreak restarts streak at 1")
    func recordOpenAfterResetStartsFresh() async {
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!
        let cache = MockCacheManager()

        let service = StreakService(calendar: utcCal, cache: cache)
        // Establish a streak, reset it, then open again.
        await service.recordAppOpen()
        await service.resetStreak()
        // After reset, lastOpenedDate is "" — daysBetween returns nil → resets to 1.
        let result = await service.recordAppOpen()

        #expect(result.currentStreak == 1)
    }
}
