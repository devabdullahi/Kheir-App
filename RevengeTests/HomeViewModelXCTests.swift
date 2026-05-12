//
//  HomeViewModelXCTests.swift
//  RevengeTests
//
//  Comprehensive XCTest coverage for HomeViewModel.

import XCTest
@testable import Revenge

// MARK: - MockStreakService

final class MockStreakService: StreakTracking, @unchecked Sendable {

    var recordResult = StreakData(
        currentStreak: 5, lastOpenedDate: "2026-04-26", longestStreak: 10
    )
    private(set) var recordCallCount = 0

    func recordAppOpen() async -> StreakData {
        recordCallCount += 1
        return recordResult
    }
    func loadStreak() async -> StreakData? { recordResult }
    func resetStreak() async {}
}

// MARK: - Fixture Helpers

private func fixtureAyah(dateKey: String) -> DailyAyah {
    DailyAyah(
        surahNumber: 1,
        surahName: "سُورَةُ ٱلْفَاتِحَةِ",
        surahEnglishName: "Al-Faatiha",
        ayahNumber: 1,
        arabicText: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
        translationText: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
        transliteration: "",
        dateString: dateKey
    )
}

private func fixtureHadith(dateKey: String) -> DailyHadith {
    DailyHadith(
        text: "Actions are judged by intentions.",
        arabicText: "إنما الأعمال بالنيات",
        source: "Sahih al-Bukhari",
        chapter: "Revelation",
        narrator: "Umar ibn al-Khattab",
        grade: "Sahih",
        dateString: dateKey
    )
}

// MARK: - HomeViewModelXCTests

@MainActor
final class HomeViewModelXCTests: XCTestCase {

    // MARK: Factory

    private func makeVM(
        api: MockAPIService = MockAPIService(),
        cache: MockCacheManager = MockCacheManager(),
        streak: MockStreakService = MockStreakService(),
        routine: MockRoutineService = MockRoutineService()
    ) -> HomeViewModel {
        HomeViewModel(
            apiService: api,
            cacheManager: cache,
            locationService: .shared,
            streakService: streak,
            routineService: routine,
            settings: .shared
        )
    }

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone.current
        return f.string(from: Date())
    }

    // MARK: - Daily Content Loading

    func test_loadDailyContent_emptyCache_fetchesFromNetwork() async throws {
        let api = MockAPIService()
        let cache = MockCacheManager()
        let vm = makeVM(api: api, cache: cache)

        await vm.loadDailyContent()

        XCTAssertNotNil(vm.dailyAyah, "dailyAyah should be populated after network fetch")
        XCTAssertNotNil(vm.dailyHadith, "dailyHadith should be populated after network fetch")
        XCTAssertEqual(api.fetchAyahCallCount, 1)
        XCTAssertEqual(api.fetchHadithCallCount, 1)
    }

    func test_loadDailyContent_cacheHit_servesCachedAyah() async throws {
        let cache = MockCacheManager()
        let seeded = fixtureAyah(dateKey: todayKey)
        cache.seedDailyAyah(seeded)

        let vm = makeVM(cache: cache)
        await vm.loadDailyContent()

        XCTAssertEqual(vm.dailyAyah?.arabicText, seeded.arabicText)
    }

    func test_loadDailyContent_cacheHit_servesCachedHadith() async throws {
        let cache = MockCacheManager()
        let seeded = fixtureHadith(dateKey: todayKey)
        cache.seedDailyHadith(seeded)

        let vm = makeVM(cache: cache)
        await vm.loadDailyContent()

        XCTAssertEqual(vm.dailyHadith?.text, seeded.text)
    }

    func test_loadDailyContent_dateGuard_preventsSecondNetworkFetch() async throws {
        let api = MockAPIService()
        let cache = MockCacheManager()
        cache.seedDailyAyah(fixtureAyah(dateKey: todayKey))
        cache.seedDailyHadith(fixtureHadith(dateKey: todayKey))

        let vm = makeVM(api: api, cache: cache)
        await vm.loadDailyContent()
        let countAfterFirst = api.fetchAyahCallCount

        await vm.loadDailyContent()

        XCTAssertEqual(api.fetchAyahCallCount, countAfterFirst,
                       "Fetch count must not increase when date-guard fires")
    }

    func test_loadDailyContent_ayahStateBecomesLoaded_onSuccess() async throws {
        let vm = makeVM()
        await vm.loadDailyContent()
        XCTAssertEqual(vm.ayahState, .loaded)
    }

    func test_loadDailyContent_hadithStateBecomesLoaded_onSuccess() async throws {
        let vm = makeVM()
        await vm.loadDailyContent()
        XCTAssertEqual(vm.hadithState, .loaded)
    }

    func test_loadDailyContent_isLoadingFalse_afterCompletion() async throws {
        let vm = makeVM()
        await vm.loadDailyContent()
        XCTAssertFalse(vm.isLoading, "isLoading must be false after loadDailyContent finishes")
    }

    // MARK: - Network Error Handling

    func test_ayahFetchError_emptyCache_stateIsFailed() async throws {
        let api = MockAPIService()
        api.ayahResult = .failure(URLError(.notConnectedToInternet))
        let vm = makeVM(api: api)
        await vm.loadDailyContent()
        XCTAssertEqual(vm.ayahState, .failed)
        XCTAssertNil(vm.dailyAyah)
    }

    func test_ayahFetchError_cacheAvailable_stateRemainsLoaded() async throws {
        // When cache has today's ayah, loadDailyContent sets .loaded immediately.
        // The subsequent network fetch is skipped by the date-guard (dailyAyah is
        // already set with today's dateString), so the error path never runs.
        let api = MockAPIService()
        api.ayahResult = .failure(URLError(.notConnectedToInternet))
        let cache = MockCacheManager()
        cache.seedDailyAyah(fixtureAyah(dateKey: todayKey))

        let vm = makeVM(api: api, cache: cache)
        await vm.loadDailyContent()

        XCTAssertEqual(vm.ayahState, .loaded)
        XCTAssertNotNil(vm.dailyAyah)
    }

    func test_hadithFetchError_usesBuiltInFallback() async throws {
        let api = MockAPIService()
        api.hadithResult = .failure(URLError(.timedOut))
        let vm = makeVM(api: api)
        await vm.loadDailyContent()
        XCTAssertNotNil(vm.dailyHadith, "Built-in fallback should be used")
        XCTAssertEqual(vm.hadithState, .offline)
    }

    func test_bothFetchErrors_ayahNil_hadithHasFallback() async throws {
        let api = MockAPIService()
        api.ayahResult = .failure(URLError(.timedOut))
        api.hadithResult = .failure(URLError(.timedOut))
        let vm = makeVM(api: api)
        await vm.loadDailyContent()
        XCTAssertNil(vm.dailyAyah)
        XCTAssertNotNil(vm.dailyHadith)
    }

    // MARK: - Arabic Hadith Fetch Path

    func test_arabicHadithFetch_populatesArabicText_onSuccess() async throws {
        let api = MockAPIService()
        let vm = makeVM(api: api)
        await vm.loadDailyContent()
        XCTAssertFalse(vm.dailyHadith?.arabicText.isEmpty ?? true,
                       "arabicText should be populated by fetchHadithSection")
    }

    func test_arabicHadithFetch_silencedOnError_producesEmptyArabicText() async throws {
        let api = MockAPIService()
        api.hadithSectionResult = .failure(URLError(.networkConnectionLost))
        let vm = makeVM(api: api)
        await vm.loadDailyContent()
        XCTAssertNotNil(vm.dailyHadith)
        XCTAssertEqual(vm.dailyHadith?.arabicText, "",
                       "arabicText should be empty when Arabic section fetch fails")
    }

    // MARK: - Refresh

    func test_refresh_bypassesDateGuard_andRefetches() async throws {
        let api = MockAPIService()
        let vm = makeVM(api: api)
        await vm.loadDailyContent()
        let countAfterLoad = api.fetchAyahCallCount

        await vm.refresh()

        XCTAssertGreaterThan(api.fetchAyahCallCount, countAfterLoad,
                             "refresh() must call fetchAyah again even if date already matches")
    }

    func test_refresh_isLoadingFalse_afterCompletion() async throws {
        let vm = makeVM()
        await vm.refresh()
        XCTAssertFalse(vm.isLoading)
    }

    // MARK: - Retry

    func test_retryAyah_triggersNewFetch_andStateLoaded() async throws {
        let api = MockAPIService()
        api.ayahResult = .failure(URLError(.timedOut))
        let vm = makeVM(api: api)
        await vm.loadDailyContent()
        let countAfterLoad = api.fetchAyahCallCount

        api.ayahResult = .success(
            Ayah(number: 1, text: "test", numberInSurah: 1, juz: 1, page: 1, hizbQuarter: 1)
        )
        await vm.retryAyah()

        XCTAssertGreaterThan(api.fetchAyahCallCount, countAfterLoad)
        XCTAssertEqual(vm.ayahState, .loaded)
    }

    func test_retryHadith_triggersNewFetch_andStateLoaded() async throws {
        let api = MockAPIService()
        api.hadithResult = .failure(URLError(.timedOut))
        let vm = makeVM(api: api)
        await vm.loadDailyContent()
        let countAfterLoad = api.fetchHadithCallCount

        api.hadithResult = .success((
            entry: HadithAPIEntry(
                hadithNumber: 1, arabicNumber: 1,
                text: "Actions are judged by intentions.",
                grades: [HadithGradeEntry(name: "Bukhari", grade: "Sahih")],
                reference: HadithReference(book: 1, hadith: 1)
            ),
            collection: .bukhari, sectionName: "Revelation", section: 1
        ))
        await vm.retryHadith()

        XCTAssertGreaterThan(api.fetchHadithCallCount, countAfterLoad)
        XCTAssertEqual(vm.hadithState, .loaded)
    }

    // MARK: - Ayah Bookmark Toggle

    func test_toggleAyahBookmark_addsBookmark() async throws {
        let api = MockAPIService()
        let cache = MockCacheManager()
        let vm = makeVM(api: api, cache: cache)
        await vm.loadDailyContent()
        guard let ayah = vm.dailyAyah else { return XCTFail("Ayah needed") }

        vm.isAyahBookmarked = false
        vm.toggleAyahBookmark()

        XCTAssertTrue(vm.isAyahBookmarked)
        let isBookmarked = await cache.isAyahBookmarked(surah: ayah.surahNumber, ayah: ayah.ayahNumber)
        XCTAssertTrue(isBookmarked)
    }

    func test_toggleAyahBookmark_removesBookmark_onSecondCall() async throws {
        let api = MockAPIService()
        let cache = MockCacheManager()
        let vm = makeVM(api: api, cache: cache)
        await vm.loadDailyContent()
        guard let ayah = vm.dailyAyah else { return XCTFail("Ayah needed") }

        vm.isAyahBookmarked = false
        vm.toggleAyahBookmark()
        vm.toggleAyahBookmark()

        XCTAssertFalse(vm.isAyahBookmarked)
        let isBookmarked = await cache.isAyahBookmarked(surah: ayah.surahNumber, ayah: ayah.ayahNumber)
        XCTAssertFalse(isBookmarked)
    }

    func test_toggleAyahBookmark_noOp_whenAyahNil() async {
        let cache = MockCacheManager()
        let vm = makeVM(cache: cache)
        vm.toggleAyahBookmark()
        let bookmarks = await cache.loadAyahBookmarks()
        XCTAssertTrue(bookmarks.isEmpty)
    }

    // MARK: - Hadith Bookmark Toggle

    func test_toggleHadithBookmark_addsBookmark() async throws {
        let api = MockAPIService()
        let cache = MockCacheManager()
        let vm = makeVM(api: api, cache: cache)
        await vm.loadDailyContent()
        guard let hadith = vm.dailyHadith else { return XCTFail("Hadith needed") }

        vm.isHadithBookmarked = false
        vm.toggleHadithBookmark()

        XCTAssertTrue(vm.isHadithBookmarked)
        let isBookmarked = await cache.isHadithBookmarked(text: hadith.text, source: hadith.source)
        XCTAssertTrue(isBookmarked)
    }

    func test_toggleHadithBookmark_removesBookmark_onSecondCall() async throws {
        let api = MockAPIService()
        let cache = MockCacheManager()
        let vm = makeVM(api: api, cache: cache)
        await vm.loadDailyContent()
        guard let hadith = vm.dailyHadith else { return XCTFail("Hadith needed") }

        vm.isHadithBookmarked = false
        vm.toggleHadithBookmark()
        vm.toggleHadithBookmark()

        XCTAssertFalse(vm.isHadithBookmarked)
        let isBookmarked = await cache.isHadithBookmarked(text: hadith.text, source: hadith.source)
        XCTAssertFalse(isBookmarked)
    }

    func test_toggleHadithBookmark_noOp_whenHadithNil() async {
        let cache = MockCacheManager()
        let vm = makeVM(cache: cache)
        vm.toggleHadithBookmark()
        let bookmarks = await cache.loadHadithBookmarks()
        XCTAssertTrue(bookmarks.isEmpty)
    }

    // MARK: - checkBookmarkStates

    func test_checkBookmarkStates_reflectsExternalCacheSeed() async throws {
        let api = MockAPIService()
        let cache = MockCacheManager()
        let vm = makeVM(api: api, cache: cache)
        await vm.loadDailyContent()
        guard let ayah = vm.dailyAyah, let hadith = vm.dailyHadith else {
            return XCTFail("Content must be loaded")
        }

        await cache.saveAyahBookmark(BookmarkedAyah(
            surahNumber: ayah.surahNumber, surahName: ayah.surahEnglishName,
            ayahNumber: ayah.ayahNumber, arabicText: ayah.arabicText,
            translationText: ayah.translationText
        ))
        await cache.saveHadithBookmark(BookmarkedHadith(
            text: hadith.text, source: hadith.source,
            narrator: hadith.narrator, grade: hadith.grade
        ))

        vm.checkBookmarkStates()

        XCTAssertTrue(vm.isAyahBookmarked)
        XCTAssertTrue(vm.isHadithBookmarked)
    }

    func test_checkBookmarkStates_returnsFalse_whenNothingBookmarked() async throws {
        let vm = makeVM()
        await vm.loadDailyContent()
        vm.checkBookmarkStates()
        XCTAssertFalse(vm.isAyahBookmarked)
        XCTAssertFalse(vm.isHadithBookmarked)
    }

    // MARK: - Share Text

    func test_shareAyahText_containsArabicAndTranslation() async throws {
        let vm = makeVM()
        await vm.loadDailyContent()
        let text = vm.shareAyahText()
        guard let ayah = vm.dailyAyah else { return XCTFail("Ayah missing") }
        XCTAssertFalse(text.isEmpty)
        XCTAssertTrue(text.contains(ayah.arabicText))
        XCTAssertTrue(text.contains(ayah.translationText))
    }

    func test_shareAyahText_containsReference() async throws {
        let vm = makeVM()
        await vm.loadDailyContent()
        guard let ayah = vm.dailyAyah else { return XCTFail("Ayah missing") }
        XCTAssertTrue(vm.shareAyahText().contains(ayah.surahEnglishName))
    }

    func test_shareAyahText_empty_whenNoAyah() {
        XCTAssertEqual(makeVM().shareAyahText(), "")
    }

    func test_shareHadithText_containsTextAndSource() async throws {
        let vm = makeVM()
        await vm.loadDailyContent()
        guard let hadith = vm.dailyHadith else { return XCTFail("Hadith missing") }
        let text = vm.shareHadithText()
        XCTAssertTrue(text.contains(hadith.text))
        XCTAssertTrue(text.contains(hadith.source))
    }

    func test_shareHadithText_includesNarrator_whenPresent() async throws {
        let cache = MockCacheManager()
        cache.seedDailyHadith(fixtureHadith(dateKey: todayKey))
        let vm = makeVM(cache: cache)
        await vm.loadDailyContent()
        XCTAssertTrue(vm.shareHadithText().contains("Umar ibn al-Khattab"))
    }

    func test_shareHadithText_empty_whenNoHadith() {
        XCTAssertEqual(makeVM().shareHadithText(), "")
    }

    // MARK: - Routine Progress

    func test_refreshRoutineProgress_isZero_whenNoRoutineExists() async {
        let vm = makeVM(routine: MockRoutineService())
        await vm.refreshRoutineProgress()
        XCTAssertEqual(vm.routineProgress, 0)
    }

    func test_refreshRoutineProgress_isGreaterThanZero_forPartialCompletion() async {
        let routineService = MockRoutineService()
        let routineType = RoutineTimeHelper.currentRoutineType()
        var routine = await routineService.generateRoutine(type: routineType, for: todayKey)
        routine.completedSteps.insert(routine.steps[0].id)
        routine.completedSteps.insert(routine.steps[1].id)
        routineService.seed(routine)

        let vm = makeVM(routine: routineService)
        await vm.refreshRoutineProgress()

        XCTAssertGreaterThan(vm.routineProgress, 0)
        XCTAssertLessThan(vm.routineProgress, 1.0)
    }

    func test_refreshRoutineProgress_isOne_forFullCompletion() async {
        let routineService = MockRoutineService()
        let routineType = RoutineTimeHelper.currentRoutineType()
        var routine = await routineService.generateRoutine(type: routineType, for: todayKey)
        for step in routine.steps { routine.completedSteps.insert(step.id) }
        routineService.seed(routine)

        let vm = makeVM(routine: routineService)
        await vm.refreshRoutineProgress()

        XCTAssertEqual(vm.routineProgress, 1.0, accuracy: 0.001)
    }

    // MARK: - Cache Write-back

    func test_networkFetch_writesDailyAyahToCache() async throws {
        let cache = MockCacheManager()
        let vm = makeVM(cache: cache)
        await vm.loadDailyContent()
        XCTAssertGreaterThanOrEqual(cache.cacheDailyAyahCallCount, 1)
    }

    func test_networkFetch_writesDailyHadithToCache() async throws {
        let cache = MockCacheManager()
        let vm = makeVM(cache: cache)
        await vm.loadDailyContent()
        XCTAssertGreaterThanOrEqual(cache.cacheDailyHadithCallCount, 1)
    }

    func test_dateGuardFire_doesNotWriteToCache_again() async throws {
        let api = MockAPIService()
        let cache = MockCacheManager()
        cache.seedDailyAyah(fixtureAyah(dateKey: todayKey))
        cache.seedDailyHadith(fixtureHadith(dateKey: todayKey))

        let vm = makeVM(api: api, cache: cache)
        await vm.loadDailyContent()
        let writesAfterFirst = cache.cacheDailyAyahCallCount

        await vm.loadDailyContent()

        XCTAssertEqual(cache.cacheDailyAyahCallCount, writesAfterFirst,
                       "Cache must not be written again when date-guard prevents fetch")
    }
}
