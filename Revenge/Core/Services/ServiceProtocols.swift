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
    func fetchRandomHadith() async throws -> (entry: HadithAPIEntry, collection: HadithCollection, sectionName: String, section: Int)
    func fetchHadithSection(editionRaw: String, section: Int) async throws -> HadithSectionResponse
}

// MARK: - Prayer Times Fetching Protocol

/// Abstracts the Aladhan API call used by PrayerTimesService.
protocol PrayerTimesFetching: Sendable {
    func fetchPrayerTimes(latitude: Double, longitude: Double, method: Int) async throws -> AladhanData
}

// MARK: - Daily Content Caching

/// Abstracts caching and loading of the daily ayah and hadith content.
protocol DailyContentCaching: AnyObject {
    func cacheDailyAyah(_ ayah: DailyAyah) async
    func loadDailyAyah(for date: String) async -> DailyAyah?
    func cacheDailyHadith(_ hadith: DailyHadith) async
    func loadDailyHadith(for date: String) async -> DailyHadith?
}

// MARK: - Ayah Bookmark Managing

/// Abstracts saving, removing, querying, and loading bookmarked ayahs.
protocol AyahBookmarkManaging: AnyObject {
    func saveAyahBookmark(_ bookmark: BookmarkedAyah) async
    func removeAyahBookmark(surah: Int, ayah: Int) async
    func removeAyahBookmark(id: UUID) async
    func isAyahBookmarked(surah: Int, ayah: Int) async -> Bool
    func loadAyahBookmarks() async -> [BookmarkedAyah]
}

// MARK: - Hadith Bookmark Managing

/// Abstracts saving, removing, querying, and loading bookmarked hadiths.
protocol HadithBookmarkManaging: AnyObject {
    func saveHadithBookmark(_ bookmark: BookmarkedHadith) async
    func removeHadithBookmark(text: String, source: String) async
    func removeHadithBookmark(id: UUID) async
    func isHadithBookmarked(text: String, source: String) async -> Bool
    func loadHadithBookmarks() async -> [BookmarkedHadith]
}

// MARK: - Journal Managing

/// Abstracts saving, updating, removing, and loading journal entries.
protocol JournalManaging: AnyObject {
    func saveJournalEntry(_ entry: JournalEntry) async
    func updateJournalEntry(_ entry: JournalEntry) async
    func removeJournalEntry(id: UUID) async
    func loadJournalEntries() async -> [JournalEntry]
}

// MARK: - Surah Caching

/// Abstracts caching and loading of surah data and surah list.
protocol SurahCaching: AnyObject {
    func cacheSurah(_ surah: CachedSurah) async
    func loadCachedSurah(_ number: Int) async -> CachedSurah?
    func cacheSurahList(_ list: [SurahInfo]) async
    func loadSurahList() async -> [SurahInfo]?
}

// MARK: - Streak Persisting

/// Abstracts raw persistence of `StreakData` (read/write only, no business logic).
protocol StreakPersisting: AnyObject {
    func saveStreak(_ data: StreakData) async
    func loadStreak() async -> StreakData?
}

// MARK: - Routine Persisting

/// Abstracts raw persistence of a `DailyRoutine` for a given type and date.
protocol RoutinePersisting: AnyObject {
    func saveRoutine(_ routine: DailyRoutine) async
    func loadRoutine(type: RoutineType, for date: String) async -> DailyRoutine?
}

// MARK: - Cache Managing Protocol

/// Composes all cache sub-protocols into a single conformance point.
/// All methods are async to ensure atomicity of read-modify-write cycles
/// and prevent data races on concurrent bookmark/journal mutations.
protocol CacheManaging: DailyContentCaching, AyahBookmarkManaging, HadithBookmarkManaging, JournalManaging, SurahCaching, StreakPersisting, RoutinePersisting {}

// MARK: - Routine Providing Protocol

/// Abstracts routine generation and progress persistence used by RoutineViewModel.
/// Conforming types: `RoutineService` (production), mock stubs (tests).
protocol RoutineProviding: AnyObject {
    /// Returns a previously persisted routine, or `nil` if one has not been generated yet.
    func loadRoutine(type: RoutineType, for date: String) async -> DailyRoutine?

    /// Persists the current progress of `routine` (i.e. its `completedSteps` set).
    func saveRoutineProgress(_ routine: DailyRoutine) async

    /// Generates a brand-new routine for the given type and date, persists it, and returns it.
    func generateRoutine(type: RoutineType, for date: String) async -> DailyRoutine
}

// MARK: - Streak Tracking Protocol

/// Abstracts app-open streak computation. Conforming types: `StreakService` (production),
/// mock stubs (tests).
protocol StreakTracking: AnyObject {
    /// Records that the app was opened today and returns the updated `StreakData`.
    /// Safe to call multiple times per day — idempotent when `lastOpenedDate` equals today.
    func recordAppOpen() async -> StreakData

    /// Returns the currently persisted `StreakData`, or `nil` if the user has never
    /// triggered `recordAppOpen()`.
    func loadStreak() async -> StreakData?

    /// Wipes the persisted streak. Intended for debugging and user-facing reset flows.
    func resetStreak() async
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
