//
//  ModelValidationTests.swift
//  RevengeTests
//
//  Unit tests for model-layer logic: HadithCollection, DailyHadith, DailyAyah,
//  MockCacheManager isolation, QuranAyahIndex boundaries, RoutineStep, DailyRoutine.

import XCTest
@testable import Revenge

final class ModelValidationTests: XCTestCase {

    // MARK: - DailyHadith

    func test_dailyHadith_defaultArabicTextIsEmpty() {
        let hadith = DailyHadith(
            text: "Actions.",
            source: "Bukhari",
            chapter: "Ch",
            narrator: "Umar",
            grade: "Sahih",
            dateString: "2026-04-26"
        )
        XCTAssertEqual(hadith.arabicText, "")
    }

    func test_dailyHadith_explicitArabicTextIsPreserved() {
        let hadith = DailyHadith(
            text: "Actions.",
            arabicText: "إنما الأعمال بالنيات",
            source: "Bukhari",
            chapter: "Ch",
            narrator: "Umar",
            grade: "Sahih",
            dateString: "2026-04-26"
        )
        XCTAssertEqual(hadith.arabicText, "إنما الأعمال بالنيات")
    }

    func test_dailyHadith_hasUniqueIDs() {
        let a = DailyHadith(text: "same", source: "s", chapter: "c", narrator: "n", grade: "g", dateString: "d")
        let b = DailyHadith(text: "same", source: "s", chapter: "c", narrator: "n", grade: "g", dateString: "d")
        XCTAssertNotEqual(a.id, b.id)
    }

    func test_dailyHadith_codableRoundTrip() throws {
        let original = DailyHadith(
            text: "Codable test.",
            arabicText: "اختبار",
            source: "TestSource",
            chapter: "TestChapter",
            narrator: "TestNarrator",
            grade: "Sahih",
            dateString: "2026-04-26"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DailyHadith.self, from: data)

        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.text, original.text)
        XCTAssertEqual(decoded.arabicText, original.arabicText)
        XCTAssertEqual(decoded.source, original.source)
        XCTAssertEqual(decoded.dateString, original.dateString)
    }

    // MARK: - DailyAyah

    func test_dailyAyah_hasUniqueIDs() {
        let a = DailyAyah(surahNumber: 1, surahName: "a", surahEnglishName: "b",
                          ayahNumber: 1, arabicText: "c", translationText: "d",
                          transliteration: "", dateString: "2026-04-26")
        let b = DailyAyah(surahNumber: 1, surahName: "a", surahEnglishName: "b",
                          ayahNumber: 1, arabicText: "c", translationText: "d",
                          transliteration: "", dateString: "2026-04-26")
        XCTAssertNotEqual(a.id, b.id)
    }

    func test_dailyAyah_codableRoundTrip() throws {
        let original = DailyAyah(
            surahNumber: 2, surahName: "البقرة", surahEnglishName: "Al-Baqarah",
            ayahNumber: 255, arabicText: "اللَّهُ لَا إِلَٰهَ إِلَّا هُوَ",
            translationText: "Allah — there is no deity except Him.", transliteration: "",
            dateString: "2026-04-26"
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(DailyAyah.self, from: data)

        XCTAssertEqual(decoded.surahNumber, 2)
        XCTAssertEqual(decoded.ayahNumber, 255)
        XCTAssertEqual(decoded.arabicText, original.arabicText)
        XCTAssertEqual(decoded.dateString, "2026-04-26")
    }

    // MARK: - HadithCollection

    func test_hadithCollection_arabicEditions_areDistinct() {
        let editions = HadithCollection.allCases.map(\.arabicEdition)
        XCTAssertEqual(editions.count, Set(editions).count)
    }

    func test_hadithCollection_displayNames_areDistinct() {
        let names = HadithCollection.allCases.map(\.displayName)
        XCTAssertEqual(names.count, Set(names).count)
    }

    func test_hadithCollection_arabicEditions_containAraPrefix() {
        for collection in HadithCollection.allCases {
            XCTAssertTrue(collection.arabicEdition.hasPrefix("ara-"),
                          "\(collection.rawValue) arabicEdition should start with 'ara-'")
        }
    }

    func test_hadithCollection_totalSections_allPositive() {
        for collection in HadithCollection.allCases {
            XCTAssertGreaterThan(collection.totalSections, 0)
        }
    }

    func test_hadithCollection_bukhari_displayName() {
        XCTAssertEqual(HadithCollection.bukhari.displayName, "Sahih al-Bukhari")
    }

    func test_hadithCollection_muslim_arabicEdition() {
        XCTAssertEqual(HadithCollection.muslim.arabicEdition, "ara-muslim")
    }

    func test_hadithCollection_allCasesCount() {
        XCTAssertEqual(HadithCollection.allCases.count, 6)
    }

    // MARK: - MockCacheManager (isolated daily content round-trips)

    func test_mockCache_dailyAyah_roundTrip() async {
        let cache = MockCacheManager()
        let ayah = DailyAyah(
            surahNumber: 3, surahName: "آل عمران", surahEnglishName: "Al-Imran",
            ayahNumber: 18, arabicText: "شَهِدَ اللَّهُ",
            translationText: "Allah witnesses.", transliteration: "",
            dateString: "2026-04-26"
        )

        await cache.cacheDailyAyah(ayah)
        let loaded = await cache.loadDailyAyah(for: "2026-04-26")

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.arabicText, ayah.arabicText)
        XCTAssertEqual(loaded?.surahNumber, 3)
        XCTAssertEqual(cache.cacheDailyAyahCallCount, 1)
        XCTAssertEqual(cache.loadDailyAyahCallCount, 1)
    }

    func test_mockCache_dailyAyah_differentDateKeys_areSeparate() async {
        let cache = MockCacheManager()
        let ayah1 = DailyAyah(surahNumber: 1, surahName: "a", surahEnglishName: "b",
                               ayahNumber: 1, arabicText: "first", translationText: "f",
                               transliteration: "", dateString: "2026-04-25")
        let ayah2 = DailyAyah(surahNumber: 2, surahName: "c", surahEnglishName: "d",
                               ayahNumber: 2, arabicText: "second", translationText: "s",
                               transliteration: "", dateString: "2026-04-26")

        await cache.cacheDailyAyah(ayah1)
        await cache.cacheDailyAyah(ayah2)

        let loaded1 = await cache.loadDailyAyah(for: "2026-04-25")
        XCTAssertEqual(loaded1?.arabicText, "first")
        let loaded2 = await cache.loadDailyAyah(for: "2026-04-26")
        XCTAssertEqual(loaded2?.arabicText, "second")
    }

    func test_mockCache_dailyAyah_returnsNil_forUnknownKey() async {
        let cache = MockCacheManager()
        let loaded = await cache.loadDailyAyah(for: "2000-01-01")
        XCTAssertNil(loaded)
    }

    func test_mockCache_dailyHadith_roundTrip() async {
        let cache = MockCacheManager()
        let hadith = DailyHadith(
            text: "Mock hadith text.",
            arabicText: "النص العربي",
            source: "Test Source",
            chapter: "Test Chapter",
            narrator: "Test Narrator",
            grade: "Sahih",
            dateString: "2026-04-26"
        )

        await cache.cacheDailyHadith(hadith)
        let loaded = await cache.loadDailyHadith(for: "2026-04-26")

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.text, hadith.text)
        XCTAssertEqual(loaded?.arabicText, hadith.arabicText)
        XCTAssertEqual(cache.cacheDailyHadithCallCount, 1)
    }

    func test_mockCache_seedDailyAyah_loadableByDate() async {
        let cache = MockCacheManager()
        let ayah = DailyAyah(surahNumber: 5, surahName: "a", surahEnglishName: "b",
                              ayahNumber: 3, arabicText: "seeded", translationText: "t",
                              transliteration: "", dateString: "2026-04-26")
        cache.seedDailyAyah(ayah)

        let loaded = await cache.loadDailyAyah(for: "2026-04-26")
        XCTAssertEqual(loaded?.arabicText, "seeded")
        XCTAssertEqual(cache.cacheDailyAyahCallCount, 0)
    }

    // MARK: - QuranAyahIndex (boundary correctness)

    func test_quranAyahIndex_surahZero_returnsNil() {
        XCTAssertNil(QuranAyahIndex.globalIndex(surah: 0, ayahInSurah: 1))
    }

    func test_quranAyahIndex_surah115_returnsNil() {
        XCTAssertNil(QuranAyahIndex.globalIndex(surah: 115, ayahInSurah: 1))
    }

    func test_quranAyahIndex_ayahZero_returnsNil() {
        XCTAssertNil(QuranAyahIndex.globalIndex(surah: 1, ayahInSurah: 0))
    }

    func test_quranAyahIndex_fatihaAyah1_isGlobalIndex1() {
        XCTAssertEqual(QuranAyahIndex.globalIndex(surah: 1, ayahInSurah: 1), 1)
    }

    func test_quranAyahIndex_fatihaAyah7_isGlobalIndex7() {
        XCTAssertEqual(QuranAyahIndex.globalIndex(surah: 1, ayahInSurah: 7), 7)
    }

    func test_quranAyahIndex_baqarahAyah1_isGlobalIndex8() {
        XCTAssertEqual(QuranAyahIndex.globalIndex(surah: 2, ayahInSurah: 1), 8)
    }

    func test_quranAyahIndex_lastAyah_isGlobalIndex6236() {
        XCTAssertEqual(QuranAyahIndex.globalIndex(surah: 114, ayahInSurah: 6), 6236)
    }

    func test_quranAyahIndex_surah114Ayah7_returnsNil_beyondBoundary() {
        XCTAssertNil(QuranAyahIndex.globalIndex(surah: 114, ayahInSurah: 7))
    }

    func test_quranAyahIndex_prefixSumsCount_equals114() {
        XCTAssertEqual(QuranAyahIndex.prefixSums.count, 114)
    }

    func test_quranAyahIndex_ayahCountsSum_is6236() {
        let total = QuranAyahIndex.ayahCounts.reduce(0, +)
        XCTAssertEqual(total, 6236)
    }

    // MARK: - RoutineStep

    func test_routineStep_arabicTextIsOptional_nilWhenOmitted() {
        let step = RoutineStep(
            type: .reflection,
            title: "Title",
            content: "Content",
            reference: "Ref"
        )
        XCTAssertNil(step.arabicText)
    }

    func test_routineStep_arabicTextPreservedWhenSet() {
        let step = RoutineStep(
            type: .dua,
            title: "Title",
            content: "Content",
            arabicText: "بسم الله",
            reference: "Ref"
        )
        XCTAssertEqual(step.arabicText, "بسم الله")
    }

    func test_routineStep_codableRoundTrip_withNilArabicText() throws {
        let step = RoutineStep(
            type: .dhikr, title: "Tasbeeh",
            content: "SubhanAllah",
            arabicText: nil,
            reference: "Muslim 2691"
        )
        let data = try JSONEncoder().encode(step)
        let decoded = try JSONDecoder().decode(RoutineStep.self, from: data)
        XCTAssertEqual(decoded.id, step.id)
        XCTAssertNil(decoded.arabicText)
        XCTAssertEqual(decoded.type, .dhikr)
    }

    // MARK: - DailyRoutine Completion

    func test_dailyRoutine_completionPercentage_emptySteps_isZero() {
        let routine = DailyRoutine(
            type: .morning, dateString: "2026-04-26", steps: [], completedSteps: []
        )
        XCTAssertEqual(routine.completionPercentage, 0)
    }

    func test_dailyRoutine_isCompleted_emptySteps_isFalse() {
        let routine = DailyRoutine(
            type: .morning, dateString: "2026-04-26", steps: [], completedSteps: []
        )
        XCTAssertFalse(routine.isCompleted)
    }

    func test_dailyRoutine_completionPercentage_allStepsComplete_isOne() {
        let steps = (0..<3).map { i in
            RoutineStep(type: .dhikr, title: "S\(i)", content: "C\(i)", reference: "R\(i)")
        }
        let routine = DailyRoutine(
            type: .morning,
            dateString: "2026-04-26",
            steps: steps,
            completedSteps: Set(steps.map(\.id))
        )
        XCTAssertEqual(routine.completionPercentage, 1.0, accuracy: 0.001)
        XCTAssertTrue(routine.isCompleted)
    }
}
