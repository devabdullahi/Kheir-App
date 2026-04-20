import Foundation

// MARK: - Ayah Fetching Protocol

/// Abstracts random-ayah and translation fetching used by HomeViewModel.
/// Conforming types: APIService (production), mock stubs (tests).
protocol AyahFetching: Sendable {
    func fetchRandomAyah(edition: String) async throws -> Ayah
    func fetchAyahTranslation(number: Int, edition: String) async throws -> AyahDetailData
}

// MARK: - Hadith Fetching Protocol

/// Abstracts random-hadith fetching used by HomeViewModel.
protocol HadithFetching: Sendable {
    func fetchRandomHadith() async throws -> (entry: HadithAPIEntry, collection: HadithCollection, sectionName: String)
}

// MARK: - Prayer Times Fetching Protocol

/// Abstracts the Aladhan API call used by PrayerTimesService.
protocol PrayerTimesFetching: Sendable {
    func fetchPrayerTimes(latitude: Double, longitude: Double, method: Int) async throws -> AladhanData
}

// MARK: - Cache Managing Protocol

/// Abstracts daily-content and bookmark persistence used by HomeViewModel and bookmark screens.
/// NOTE: CacheManager is intentionally NOT an actor for now.
/// TODO(phase2): race when Home + Bookmarks mutate concurrently; convert to actor with widget App Group work
protocol CacheManaging: AnyObject {
    // Daily content
    func cacheDailyAyah(_ ayah: DailyAyah)
    func loadDailyAyah(for date: String) -> DailyAyah?
    func cacheDailyHadith(_ hadith: DailyHadith)
    func loadDailyHadith(for date: String) -> DailyHadith?

    // Ayah bookmarks
    func saveAyahBookmark(_ bookmark: BookmarkedAyah)
    func removeAyahBookmark(surah: Int, ayah: Int)
    func removeAyahBookmark(id: UUID)
    func isAyahBookmarked(surah: Int, ayah: Int) -> Bool
    func loadAyahBookmarks() -> [BookmarkedAyah]

    // Hadith bookmarks
    func saveHadithBookmark(_ bookmark: BookmarkedHadith)
    func removeHadithBookmark(text: String, source: String)
    func removeHadithBookmark(id: UUID)
    func isHadithBookmarked(text: String, source: String) -> Bool
    func loadHadithBookmarks() -> [BookmarkedHadith]

    // Streak persistence
    func saveStreak(_ data: StreakData)
    func loadStreak() -> StreakData?

    // Routine persistence
    func saveRoutine(_ routine: DailyRoutine)
    func loadRoutine(type: RoutineType, for date: String) -> DailyRoutine?
}

// MARK: - Routine Providing Protocol

/// Abstracts routine generation and progress persistence used by RoutineViewModel.
/// Conforming types: `RoutineService` (production), mock stubs (tests).
protocol RoutineProviding: AnyObject {
    /// Returns a previously persisted routine, or `nil` if one has not been generated yet.
    func loadRoutine(type: RoutineType, for date: String) -> DailyRoutine?

    /// Persists the current progress of `routine` (i.e. its `completedSteps` set).
    func saveRoutineProgress(_ routine: DailyRoutine)

    /// Generates a brand-new routine for the given type and date, persists it, and returns it.
    func generateRoutine(type: RoutineType, for date: String) -> DailyRoutine
}

// MARK: - Streak Tracking Protocol

/// Abstracts app-open streak computation. Conforming types: `StreakService` (production),
/// mock stubs (tests).
protocol StreakTracking: AnyObject {
    /// Records that the app was opened today and returns the updated `StreakData`.
    /// Safe to call multiple times per day — idempotent when `lastOpenedDate` equals today.
    func recordAppOpen() -> StreakData

    /// Returns the currently persisted `StreakData`, or `nil` if the user has never
    /// triggered `recordAppOpen()`.
    func loadStreak() -> StreakData?

    /// Wipes the persisted streak. Intended for debugging and user-facing reset flows.
    func resetStreak()
}

// MARK: - APIService Conformances

extension APIService: AyahFetching {}
extension APIService: HadithFetching {}
extension APIService: PrayerTimesFetching {}

// MARK: - CacheManager Conformance

extension CacheManager: CacheManaging {}

// MARK: - StreakService Conformance

extension StreakService: StreakTracking {}

// MARK: - RoutineService Conformance

extension RoutineService: RoutineProviding {}
