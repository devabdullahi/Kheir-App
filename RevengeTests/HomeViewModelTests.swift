import Testing
import Foundation
@testable import Revenge

// MARK: - Fixture helpers

private func makeDailyAyah(dateKey: String) -> DailyAyah {
    DailyAyah(
        surahNumber: 1,
        surahName: "سُورَةُ ٱلْفَاتِحَةِ",
        surahEnglishName: "Al-Faatiha",
        ayahNumber: 1,
        arabicText: "بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ",
        translationText: "In the name of Allah, the Entirely Merciful, the Especially Merciful.",
        transliteration: "Bismillahi ar-rahmani ar-raheem",
        dateString: dateKey
    )
}

private func makeDailyHadith(dateKey: String) -> DailyHadith {
    DailyHadith(
        text: "Actions are judged by intentions.",
        source: "Sahih al-Bukhari",
        chapter: "Revelation",
        narrator: "Umar ibn al-Khattab",
        grade: "Sahih",
        dateString: dateKey
    )
}

// MARK: - HomeViewModelTests

// NOTE(delta-round3): Tests are written against the forthcoming DI-enabled HomeViewModel
// init(apiService: any AyahFetching & HadithFetching, cacheManager: any CacheManaging, ...).
// They will not compile until Alpha's ServiceProtocols.swift lands and HomeViewModel adopts
// the new initialiser. That is expected per round-2 brief.

@MainActor
@Suite("HomeViewModel", .serialized)
struct HomeViewModelTests {

    // MARK: - Helpers

    private func makeViewModel(
        api: MockAPIService = MockAPIService(),
        cache: MockCacheManager = MockCacheManager()
    ) -> HomeViewModel {
        HomeViewModel(
            apiService: api,
            cacheManager: cache,
            locationService: .shared,
            settings: .shared
        )
    }

    private var todayKey: String { Date().dayKey }

    // MARK: - Tests

    // 1. Network path for ayah — fresh launch, empty cache
    @Test("Loads ayah from network on first launch")
    func loadsAyahFromNetworkOnFirstLaunch() async throws {
        let api = MockAPIService()
        let cache = MockCacheManager()

        let vm = makeViewModel(api: api, cache: cache)
        await vm.loadDailyContent()

        // Fire-and-forget Task inside loadDailyContent — yield briefly.
        // RISK(delta-round3 #3): replace sleep with structured concurrency once
        // Alpha exposes an awaitable handle from loadDailyContent.
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(vm.dailyAyah != nil)
        #expect(api.fetchAyahCallCount == 1)
    }

    // 2. Network path for hadith — fresh launch, empty cache
    @Test("Loads hadith from network on first launch")
    func loadsHadithFromNetworkOnFirstLaunch() async throws {
        let api = MockAPIService()
        let cache = MockCacheManager()

        let vm = makeViewModel(api: api, cache: cache)
        await vm.loadDailyContent()

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(vm.dailyHadith != nil)
        #expect(api.fetchHadithCallCount == 1)
    }

    // 3. Cache fallback when API throws — ayah
    @Test("Serves ayah from cache when API throws")
    func servesAyahFromCacheWhenAPIThrows() async throws {
        let api = MockAPIService()
        api.ayahResult = .failure(URLError(.notConnectedToInternet))

        let cache = MockCacheManager()
        let seeded = makeDailyAyah(dateKey: todayKey)
        cache.seedDailyAyah(seeded)

        let vm = makeViewModel(api: api, cache: cache)
        await vm.loadDailyContent()

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(vm.dailyAyah?.dateString == todayKey)
        #expect(vm.dailyAyah?.arabicText == seeded.arabicText)
    }

    // 4. Cache fallback when API throws — hadith
    @Test("Serves hadith from cache when API throws")
    func servesHadithFromCacheWhenAPIThrows() async throws {
        let api = MockAPIService()
        api.hadithResult = .failure(URLError(.notConnectedToInternet))

        let cache = MockCacheManager()
        let seeded = makeDailyHadith(dateKey: todayKey)
        cache.seedDailyHadith(seeded)

        let vm = makeViewModel(api: api, cache: cache)
        await vm.loadDailyContent()

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(vm.dailyHadith?.dateString == todayKey)
        #expect(vm.dailyHadith?.text == seeded.text)
    }

    // 5. Date-guard: no API call when cache already has today's ayah
    @Test("Does not refetch if ayah date key matches today")
    func doesNotRefetchIfAyahDateKeyMatches() async throws {
        let api = MockAPIService()

        let cache = MockCacheManager()
        cache.seedDailyAyah(makeDailyAyah(dateKey: todayKey))
        cache.seedDailyHadith(makeDailyHadith(dateKey: todayKey))

        let vm = makeViewModel(api: api, cache: cache)
        await vm.loadDailyContent()

        try await Task.sleep(nanoseconds: 100_000_000)

        // The date guard inside fetchDailyAyah checks dailyAyah?.dateString == dateKey.
        // With cache seeded, vm.dailyAyah is set synchronously before the async Task fires,
        // so the guard returns early and fetchAyah is never called.
        #expect(api.fetchAyahCallCount == 0)
    }

    // 6. Error with empty cache — no crash, dailyAyah stays nil
    @Test("Handles API error gracefully with no cache")
    func handlesAPIErrorGracefullyWithNoCache() async throws {
        let api = MockAPIService()
        api.ayahResult = .failure(URLError(.timedOut))
        api.hadithResult = .failure(URLError(.timedOut))

        let cache = MockCacheManager()

        let vm = makeViewModel(api: api, cache: cache)
        await vm.loadDailyContent()

        try await Task.sleep(nanoseconds: 100_000_000)

        // No crash. Ayah remains nil (hadith uses built-in fallback, so only check ayah here).
        #expect(vm.dailyAyah == nil)
    }

    // 7. refresh() bypasses date guard and triggers a new network fetch
    // NOTE(delta-round3 #3): relies on Alpha adding a public `refresh()` to HomeViewModel.
    @Test("Refresh bypasses date guard and refetches")
    func refreshBypassesDateGuardAndRefetches() async throws {
        let api = MockAPIService()
        let cache = MockCacheManager()

        let vm = makeViewModel(api: api, cache: cache)

        // Initial load
        await vm.loadDailyContent()
        try await Task.sleep(nanoseconds: 100_000_000)
        let countAfterLoad = api.fetchAyahCallCount

        // Explicit refresh should bypass the date guard
        await vm.refresh()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(api.fetchAyahCallCount > countAfterLoad)
    }
}
