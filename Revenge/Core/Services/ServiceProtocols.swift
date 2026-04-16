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
}

// MARK: - APIService Conformances

extension APIService: AyahFetching {}
extension APIService: HadithFetching {}
extension APIService: PrayerTimesFetching {}

// MARK: - CacheManager Conformance

extension CacheManager: CacheManaging {}
