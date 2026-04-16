import Foundation
@testable import Revenge

// MARK: - MockAPIService

final class MockAPIService: AyahFetching, HadithFetching, @unchecked Sendable {

    // MARK: Configurable results
    var ayahResult: Result<Ayah, Error> = .success(
        Ayah(number: 1, text: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
             numberInSurah: 1, juz: 1, page: 1, hizbQuarter: 1)
    )
    var ayahTranslationResult: Result<AyahDetailData, Error> = .success(
        AyahDetailData(
            number: 1,
            text: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
            numberInSurah: 1,
            surah: AyahDetailData.AyahSurahInfo(
                number: 1,
                name: "سُورَةُ ٱلْفَاتِحَةِ",
                englishName: "Al-Faatiha",
                englishNameTranslation: "The Opening"
            )
        )
    )
    var hadithResult: Result<(entry: HadithAPIEntry, collection: HadithCollection, sectionName: String), Error> = .success(
        (
            entry: HadithAPIEntry(
                hadithNumber: 1,
                arabicNumber: 1,
                text: "Actions are judged by intentions.",
                grades: [HadithGradeEntry(name: "Sahih al-Bukhari", grade: "Sahih")],
                reference: HadithReference(book: 1, hadith: 1)
            ),
            collection: .bukhari,
            sectionName: "Revelation"
        )
    )

    // MARK: Call counts
    private(set) var fetchAyahCallCount = 0
    private(set) var fetchAyahTranslationCallCount = 0
    private(set) var fetchHadithCallCount = 0

    // MARK: AyahFetching

    func fetchRandomAyah(edition: String) async throws -> Ayah {
        fetchAyahCallCount += 1
        return try ayahResult.get()
    }

    func fetchAyahTranslation(number: Int, edition: String) async throws -> AyahDetailData {
        fetchAyahTranslationCallCount += 1
        return try ayahTranslationResult.get()
    }

    // MARK: HadithFetching

    func fetchRandomHadith() async throws -> (entry: HadithAPIEntry, collection: HadithCollection, sectionName: String) {
        fetchHadithCallCount += 1
        return try hadithResult.get()
    }
}

// MARK: - MockCacheManager

final class MockCacheManager: CacheManaging {

    // MARK: In-memory stores
    private var dailyAyahStore: [String: DailyAyah] = [:]
    private var dailyHadithStore: [String: DailyHadith] = [:]
    private var ayahBookmarks: [BookmarkedAyah] = []
    private var hadithBookmarks: [BookmarkedHadith] = []

    // MARK: Call counts
    private(set) var cacheDailyAyahCallCount = 0
    private(set) var cacheDailyHadithCallCount = 0
    private(set) var loadDailyAyahCallCount = 0
    private(set) var loadDailyHadithCallCount = 0

    // MARK: Seeding helpers (for test setup)

    func seedDailyAyah(_ ayah: DailyAyah) {
        dailyAyahStore[ayah.dateString] = ayah
    }

    func seedDailyHadith(_ hadith: DailyHadith) {
        dailyHadithStore[hadith.dateString] = hadith
    }

    // MARK: CacheManaging — Daily Ayah

    func cacheDailyAyah(_ ayah: DailyAyah) {
        cacheDailyAyahCallCount += 1
        dailyAyahStore[ayah.dateString] = ayah
    }

    func loadDailyAyah(for dateKey: String) -> DailyAyah? {
        loadDailyAyahCallCount += 1
        return dailyAyahStore[dateKey]
    }

    // MARK: CacheManaging — Daily Hadith

    func cacheDailyHadith(_ hadith: DailyHadith) {
        cacheDailyHadithCallCount += 1
        dailyHadithStore[hadith.dateString] = hadith
    }

    func loadDailyHadith(for dateKey: String) -> DailyHadith? {
        loadDailyHadithCallCount += 1
        return dailyHadithStore[dateKey]
    }

    // MARK: CacheManaging — Ayah Bookmarks

    func saveAyahBookmark(_ bookmark: BookmarkedAyah) {
        ayahBookmarks.removeAll { $0.surahNumber == bookmark.surahNumber && $0.ayahNumber == bookmark.ayahNumber }
        ayahBookmarks.insert(bookmark, at: 0)
    }

    func removeAyahBookmark(id: UUID) {
        ayahBookmarks.removeAll { $0.id == id }
    }

    func removeAyahBookmark(surah: Int, ayah: Int) {
        ayahBookmarks.removeAll { $0.surahNumber == surah && $0.ayahNumber == ayah }
    }

    func isAyahBookmarked(surah: Int, ayah: Int) -> Bool {
        ayahBookmarks.contains { $0.surahNumber == surah && $0.ayahNumber == ayah }
    }

    func loadAyahBookmarks() -> [BookmarkedAyah] {
        ayahBookmarks
    }

    // MARK: CacheManaging — Hadith Bookmarks

    func saveHadithBookmark(_ bookmark: BookmarkedHadith) {
        hadithBookmarks.removeAll { $0.text == bookmark.text }
        hadithBookmarks.insert(bookmark, at: 0)
    }

    func removeHadithBookmark(id: UUID) {
        hadithBookmarks.removeAll { $0.id == id }
    }

    func removeHadithBookmark(text: String, source: String) {
        hadithBookmarks.removeAll { $0.text == text && $0.source == source }
    }

    func isHadithBookmarked(text: String, source: String) -> Bool {
        hadithBookmarks.contains { $0.text == text && $0.source == source }
    }

    func loadHadithBookmarks() -> [BookmarkedHadith] {
        hadithBookmarks
    }
}
