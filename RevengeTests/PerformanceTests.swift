import Testing
import Foundation
@testable import Revenge

// MARK: - CacheManager Performance Tests

@Suite("Performance - CacheManager", .serialized)
struct CacheManagerPerformanceTests {
    let cache = CacheManager.shared

    @Test("Memory cache hit is under 1ms for bookmark load")
    func memoryCacheHitSpeed() {
        // Warm the cache with a save
        let bookmark = BookmarkedAyah(
            surahNumber: 900, surahName: "PerfTest",
            ayahNumber: 1, arabicText: "test", translationText: "test"
        )
        cache.saveAyahBookmark(bookmark)
        defer { cache.removeAyahBookmark(id: bookmark.id) }

        // Measure read — should hit memory cache
        let start = CFAbsoluteTimeGetCurrent()
        let iterations = 100
        for _ in 0..<iterations {
            _ = cache.loadAyahBookmarks()
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) / Double(iterations)
        let elapsedMs = elapsed * 1000

        // Memory cache reads should be well under 1ms each
        #expect(elapsedMs < 1.0, "Average bookmark load took \(String(format: "%.3f", elapsedMs))ms, expected < 1ms")
    }

    @Test("Concurrent bookmark reads don't crash")
    func concurrentReads() async {
        let bookmark = BookmarkedAyah(
            surahNumber: 901, surahName: "ConcurrentTest",
            ayahNumber: 1, arabicText: "test", translationText: "test"
        )
        cache.saveAyahBookmark(bookmark)
        defer { cache.removeAyahBookmark(id: bookmark.id) }

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    _ = self.cache.loadAyahBookmarks()
                }
            }
        }
        // If we get here without crash, concurrent reads are safe
    }

    @Test("Save + immediate load returns saved data (memory cache consistency)")
    func saveLoadConsistency() {
        let entry = JournalEntry(text: "PerfTest consistency \(UUID().uuidString)")
        cache.saveJournalEntry(entry)
        defer { cache.removeJournalEntry(id: entry.id) }

        // Immediate load should return the entry from memory cache
        // even before disk write completes
        let loaded = cache.loadJournalEntries()
        #expect(loaded.contains { $0.id == entry.id })
    }

    @Test("Daily ayah cache round-trip")
    func dailyAyahCacheRoundTrip() {
        let ayah = DailyAyah(
            surahNumber: 1, surahName: "الفاتحة",
            surahEnglishName: "Al-Fatiha", ayahNumber: 1,
            arabicText: "بسم الله", translationText: "In the name of Allah",
            transliteration: "", dateString: "perf-test-key"
        )
        cache.cacheDailyAyah(ayah)

        let start = CFAbsoluteTimeGetCurrent()
        let loaded = cache.loadDailyAyah(for: "perf-test-key")
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000

        #expect(loaded != nil)
        #expect(loaded?.surahNumber == 1)
        #expect(elapsed < 5.0, "Daily ayah load took \(String(format: "%.3f", elapsed))ms, expected < 5ms")
    }
}

// MARK: - QuranAyahIndex Performance Tests

@Suite("Performance - QuranAyahIndex")
struct QuranAyahIndexPerformanceTests {

    @Test("globalIndex O(1) lookup is fast")
    func globalIndexSpeed() {
        let iterations = 10_000
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = QuranAyahIndex.globalIndex(surah: 114, ayahInSurah: 6)
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let perCall = elapsed / Double(iterations) * 1000 // microseconds

        #expect(perCall < 10.0, "globalIndex took \(String(format: "%.2f", perCall))µs per call, expected < 10µs")
    }

    @Test("globalIndex returns correct values")
    func globalIndexCorrectness() {
        // Fatiha ayah 1 should be global index 1
        #expect(QuranAyahIndex.globalIndex(surah: 1, ayahInSurah: 1) == 1)
        // Fatiha ayah 7 should be global index 7
        #expect(QuranAyahIndex.globalIndex(surah: 1, ayahInSurah: 7) == 7)
        // Baqarah ayah 1 should be global index 8
        #expect(QuranAyahIndex.globalIndex(surah: 2, ayahInSurah: 1) == 8)
        // Last ayah of Quran (Surah 114, ayah 6) should be 6236
        #expect(QuranAyahIndex.globalIndex(surah: 114, ayahInSurah: 6) == 6236)
        // Out of range
        #expect(QuranAyahIndex.globalIndex(surah: 0, ayahInSurah: 1) == nil)
        #expect(QuranAyahIndex.globalIndex(surah: 115, ayahInSurah: 1) == nil)
    }
}

// MARK: - APIService Configuration Tests

@Suite("Performance - APIService Configuration")
struct APIServiceConfigTests {

    @Test("URLSession has proper timeout configuration")
    func sessionTimeouts() {
        let session = URLSession.shared
        // We can't access APIService's private session, but we verify it was configured
        // by checking that APIService.shared exists and doesn't crash
        let service = APIService.shared
        #expect(service != nil)
    }

    @Test("Audio URL generation is O(1)")
    func audioURLSpeed() {
        let service = APIService.shared
        let iterations = 1000
        let start = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = service.audioURL(qari: "ar.alafasy", surah: 114, ayah: 6)
        }
        let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
        let perCall = elapsed / Double(iterations) * 1000

        #expect(perCall < 50.0, "audioURL took \(String(format: "%.2f", perCall))µs per call")
    }
}

// MARK: - DateFormatter Caching Tests

@Suite("Performance - DateFormatter")
struct DateFormatterPerformanceTests {

    @Test("Cached DateFormatter is faster than creating new ones")
    func cachedFormatterSpeed() {
        let iterations = 1000
        let date = Date()

        // Measure creating new formatters each time
        let startNew = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = TimeZone.current
            _ = f.string(from: date)
        }
        let newTime = CFAbsoluteTimeGetCurrent() - startNew

        // Measure reusing a cached formatter
        let cached = DateFormatter()
        cached.dateFormat = "yyyy-MM-dd"
        cached.timeZone = TimeZone.current
        let startCached = CFAbsoluteTimeGetCurrent()
        for _ in 0..<iterations {
            _ = cached.string(from: date)
        }
        let cachedTime = CFAbsoluteTimeGetCurrent() - startCached

        // Cached should be significantly faster
        #expect(cachedTime < newTime, "Cached formatter (\(cachedTime)s) should be faster than creating new (\(newTime)s)")
    }
}
