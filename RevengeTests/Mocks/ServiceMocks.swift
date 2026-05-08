import Foundation
@testable import Revenge

// MARK: - MockAPIService

final class MockAPIService: AyahFetching, HadithFetching, @unchecked Sendable {

    // MARK: Lock

    private let lock = NSLock()

    // MARK: Configurable results

    private var _ayahResult: Result<Ayah, Error> = .success(
        Ayah(number: 1, text: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
             numberInSurah: 1, juz: 1, page: 1, hizbQuarter: 1)
    )
    var ayahResult: Result<Ayah, Error> {
        get { lock.lock(); defer { lock.unlock() }; return _ayahResult }
        set { lock.lock(); defer { lock.unlock() }; _ayahResult = newValue }
    }

    private var _ayahTranslationResult: Result<AyahDetailData, Error> = .success(
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
    var ayahTranslationResult: Result<AyahDetailData, Error> {
        get { lock.lock(); defer { lock.unlock() }; return _ayahTranslationResult }
        set { lock.lock(); defer { lock.unlock() }; _ayahTranslationResult = newValue }
    }

    private var _hadithResult: Result<(entry: HadithAPIEntry, collection: HadithCollection, sectionName: String, section: Int), Error> = .success(
        (
            entry: HadithAPIEntry(
                hadithNumber: 1,
                arabicNumber: 1,
                text: "Actions are judged by intentions.",
                grades: [HadithGradeEntry(name: "Sahih al-Bukhari", grade: "Sahih")],
                reference: HadithReference(book: 1, hadith: 1)
            ),
            collection: .bukhari,
            sectionName: "Revelation",
            section: 1
        )
    )
    var hadithResult: Result<(entry: HadithAPIEntry, collection: HadithCollection, sectionName: String, section: Int), Error> {
        get { lock.lock(); defer { lock.unlock() }; return _hadithResult }
        set { lock.lock(); defer { lock.unlock() }; _hadithResult = newValue }
    }

    private var _hadithSectionResult: Result<HadithSectionResponse, Error>?
    var hadithSectionResult: Result<HadithSectionResponse, Error>? {
        get { lock.lock(); defer { lock.unlock() }; return _hadithSectionResult }
        set { lock.lock(); defer { lock.unlock() }; _hadithSectionResult = newValue }
    }

    // MARK: Call counts

    private var _fetchAyahCallCount = 0
    private(set) var fetchAyahCallCount: Int {
        get { lock.lock(); defer { lock.unlock() }; return _fetchAyahCallCount }
        set { lock.lock(); defer { lock.unlock() }; _fetchAyahCallCount = newValue }
    }

    private var _fetchAyahTranslationCallCount = 0
    private(set) var fetchAyahTranslationCallCount: Int {
        get { lock.lock(); defer { lock.unlock() }; return _fetchAyahTranslationCallCount }
        set { lock.lock(); defer { lock.unlock() }; _fetchAyahTranslationCallCount = newValue }
    }

    private var _fetchHadithCallCount = 0
    private(set) var fetchHadithCallCount: Int {
        get { lock.lock(); defer { lock.unlock() }; return _fetchHadithCallCount }
        set { lock.lock(); defer { lock.unlock() }; _fetchHadithCallCount = newValue }
    }

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

    func fetchRandomHadith() async throws -> (entry: HadithAPIEntry, collection: HadithCollection, sectionName: String, section: Int) {
        fetchHadithCallCount += 1
        return try hadithResult.get()
    }

    func fetchHadithSection(editionRaw: String, section: Int) async throws -> HadithSectionResponse {
        if let result = hadithSectionResult {
            return try result.get()
        }
        // Default: return a matching Arabic entry so the language toggle works in tests
        let arabicEntry = HadithAPIEntry(
            hadithNumber: 1,
            arabicNumber: 1,
            text: "إنما الأعمال بالنيات",
            grades: [HadithGradeEntry(name: "Sahih al-Bukhari", grade: "Sahih")],
            reference: HadithReference(book: 1, hadith: 1)
        )
        return HadithSectionResponse(
            metadata: HadithMetadata(name: "", section: nil, sectionDetail: nil),
            hadiths: [arabicEntry]
        )
    }
}

// MARK: - MockCacheManager

final class MockCacheManager: CacheManaging {

    // MARK: In-memory stores
    private var dailyAyahStore: [String: DailyAyah] = [:]
    private var dailyHadithStore: [String: DailyHadith] = [:]
    private var ayahBookmarks: [BookmarkedAyah] = []
    private var hadithBookmarks: [BookmarkedHadith] = []
    private var journalEntries: [JournalEntry] = []
    private var surahStore: [Int: CachedSurah] = [:]
    private var surahList: [SurahInfo]?
    private var streakStore: StreakData?
    private var routineStore: [String: DailyRoutine] = [:]

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

    func cacheDailyAyah(_ ayah: DailyAyah) async {
        cacheDailyAyahCallCount += 1
        dailyAyahStore[ayah.dateString] = ayah
    }

    func loadDailyAyah(for dateKey: String) async -> DailyAyah? {
        loadDailyAyahCallCount += 1
        return dailyAyahStore[dateKey]
    }

    // MARK: CacheManaging — Daily Hadith

    func cacheDailyHadith(_ hadith: DailyHadith) async {
        cacheDailyHadithCallCount += 1
        dailyHadithStore[hadith.dateString] = hadith
    }

    func loadDailyHadith(for dateKey: String) async -> DailyHadith? {
        loadDailyHadithCallCount += 1
        return dailyHadithStore[dateKey]
    }

    // MARK: CacheManaging — Ayah Bookmarks

    func saveAyahBookmark(_ bookmark: BookmarkedAyah) async {
        ayahBookmarks.removeAll { $0.surahNumber == bookmark.surahNumber && $0.ayahNumber == bookmark.ayahNumber }
        ayahBookmarks.insert(bookmark, at: 0)
    }

    func removeAyahBookmark(id: UUID) async {
        ayahBookmarks.removeAll { $0.id == id }
    }

    func removeAyahBookmark(surah: Int, ayah: Int) async {
        ayahBookmarks.removeAll { $0.surahNumber == surah && $0.ayahNumber == ayah }
    }

    func isAyahBookmarked(surah: Int, ayah: Int) async -> Bool {
        ayahBookmarks.contains { $0.surahNumber == surah && $0.ayahNumber == ayah }
    }

    func loadAyahBookmarks() async -> [BookmarkedAyah] {
        ayahBookmarks
    }

    // MARK: CacheManaging — Hadith Bookmarks

    func saveHadithBookmark(_ bookmark: BookmarkedHadith) async {
        hadithBookmarks.removeAll { $0.text == bookmark.text }
        hadithBookmarks.insert(bookmark, at: 0)
    }

    func removeHadithBookmark(id: UUID) async {
        hadithBookmarks.removeAll { $0.id == id }
    }

    func removeHadithBookmark(text: String, source: String) async {
        hadithBookmarks.removeAll { $0.text == text && $0.source == source }
    }

    func isHadithBookmarked(text: String, source: String) async -> Bool {
        hadithBookmarks.contains { $0.text == text && $0.source == source }
    }

    func loadHadithBookmarks() async -> [BookmarkedHadith] {
        hadithBookmarks
    }

    // MARK: CacheManaging — Journal

    func saveJournalEntry(_ entry: JournalEntry) async {
        journalEntries.insert(entry, at: 0)
    }

    func updateJournalEntry(_ entry: JournalEntry) async {
        if let index = journalEntries.firstIndex(where: { $0.id == entry.id }) {
            journalEntries[index] = entry
        }
    }

    func removeJournalEntry(id: UUID) async {
        journalEntries.removeAll { $0.id == id }
    }

    func loadJournalEntries() async -> [JournalEntry] {
        journalEntries
    }

    // MARK: CacheManaging — Surah

    func cacheSurah(_ surah: CachedSurah) async {
        surahStore[surah.surahNumber] = surah
    }

    func loadCachedSurah(_ number: Int) async -> CachedSurah? {
        surahStore[number]
    }

    func cacheSurahList(_ list: [SurahInfo]) async {
        surahList = list
    }

    func loadSurahList() async -> [SurahInfo]? {
        surahList
    }

    // MARK: CacheManaging — Streak

    func saveStreak(_ data: StreakData) async {
        streakStore = data
    }

    func loadStreak() async -> StreakData? {
        streakStore
    }

    // MARK: CacheManaging — Routines

    func saveRoutine(_ routine: DailyRoutine) async {
        routineStore["\(routine.type.rawValue)_\(routine.dateString)"] = routine
    }

    func loadRoutine(type: RoutineType, for date: String) async -> DailyRoutine? {
        routineStore["\(type.rawValue)_\(date)"]
    }
}

// MARK: - MockRoutineService

final class MockRoutineService: RoutineProviding {

    // MARK: In-memory stores
    private var store: [String: DailyRoutine] = [:]

    // MARK: Call counts
    private(set) var generateCallCount = 0
    private(set) var saveProgressCallCount = 0

    // MARK: Seeding helper (for test setup)

    func seed(_ routine: DailyRoutine) {
        store["\(routine.type.rawValue)_\(routine.dateString)"] = routine
    }

    // MARK: RoutineProviding

    func loadRoutine(type: RoutineType, for date: String) async -> DailyRoutine? {
        store["\(type.rawValue)_\(date)"]
    }

    func saveRoutineProgress(_ routine: DailyRoutine) async {
        saveProgressCallCount += 1
        store["\(routine.type.rawValue)_\(routine.dateString)"] = routine
    }

    func generateRoutine(type: RoutineType, for date: String) async -> DailyRoutine {
        generateCallCount += 1
        if let existing = store["\(type.rawValue)_\(date)"] {
            return existing
        }
        // Return a minimal 6-step routine so tests that check step count work correctly.
        let steps = (0..<6).map { i in
            RoutineStep(
                type: i == 0 ? .dua : (i == 1 ? (type == .morning ? .ayah : .hadith) : (i < 5 ? .dhikr : .reflection)),
                title: "Step \(i + 1)",
                content: "Content for step \(i + 1)",
                arabicText: i < 3 ? "عربي \(i + 1)" : nil,
                reference: "Reference \(i + 1)"
            )
        }
        let routine = DailyRoutine(type: type, dateString: date, steps: steps)
        store["\(type.rawValue)_\(date)"] = routine
        return routine
    }
}
