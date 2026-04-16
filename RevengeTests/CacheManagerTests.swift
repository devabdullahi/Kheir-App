import Testing
import Foundation
@testable import Revenge

@Suite("CacheManager - Ayah Bookmarks", .serialized)
struct CacheManagerAyahTests {
    let cache = CacheManager.shared

    @Test("Save and load ayah bookmark")
    func saveAndLoadAyahBookmark() {
        let bookmark = BookmarkedAyah(
            surahNumber: 501, surahName: "CacheTest-Fatiha",
            ayahNumber: 1, arabicText: "بِسْمِ اللَّهِ",
            translationText: "In the name of Allah"
        )
        cache.saveAyahBookmark(bookmark)
        defer { cache.removeAyahBookmark(id: bookmark.id) }
        let loaded = cache.loadAyahBookmarks()
        #expect(loaded.contains { $0.id == bookmark.id })
    }

    @Test("isAyahBookmarked returns true for saved ayah")
    func isAyahBookmarkedTrue() {
        let bookmark = BookmarkedAyah(
            surahNumber: 502, surahName: "CacheTest",
            ayahNumber: 42, arabicText: "test", translationText: "test"
        )
        cache.saveAyahBookmark(bookmark)
        defer { cache.removeAyahBookmark(id: bookmark.id) }
        #expect(cache.isAyahBookmarked(surah: 502, ayah: 42) == true)
    }

    @Test("isAyahBookmarked returns false for unsaved ayah")
    func isAyahBookmarkedFalse() {
        #expect(cache.isAyahBookmarked(surah: 503, ayah: 999) == false)
    }

    @Test("Remove ayah bookmark by surah and ayah")
    func removeAyahBookmarkBySurahAyah() {
        let bookmark = BookmarkedAyah(
            surahNumber: 504, surahName: "CacheTest",
            ayahNumber: 1, arabicText: "a", translationText: "b"
        )
        cache.saveAyahBookmark(bookmark)
        #expect(cache.isAyahBookmarked(surah: 504, ayah: 1) == true)
        cache.removeAyahBookmark(surah: 504, ayah: 1)
        #expect(cache.isAyahBookmarked(surah: 504, ayah: 1) == false)
    }
}

@Suite("CacheManager - Hadith Bookmarks", .serialized)
struct CacheManagerHadithTests {
    let cache = CacheManager.shared

    @Test("Save and load hadith bookmark")
    func saveAndLoadHadithBookmark() {
        let id = UUID().uuidString.prefix(8)
        let bookmark = BookmarkedHadith(
            text: "CM hadith \(id)",
            source: "CMSource\(id)", narrator: "TestNarrator", grade: "Sahih"
        )
        cache.saveHadithBookmark(bookmark)
        defer { cache.removeHadithBookmark(id: bookmark.id) }
        let loaded = cache.loadHadithBookmarks()
        #expect(loaded.contains { $0.id == bookmark.id })
    }

    @Test("isHadithBookmarked works correctly")
    func isHadithBookmarked() {
        let id = UUID().uuidString.prefix(8)
        let text = "CM unique hadith \(id)"
        let source = "CMUniqueSource\(id)"
        let bookmark = BookmarkedHadith(text: text, source: source, narrator: "", grade: "Hasan")
        cache.saveHadithBookmark(bookmark)
        defer { cache.removeHadithBookmark(id: bookmark.id) }
        #expect(cache.isHadithBookmarked(text: text, source: source) == true)
        #expect(cache.isHadithBookmarked(text: "nonexistent_\(id)", source: "nowhere_\(id)") == false)
    }

    @Test("Remove hadith bookmark by text and source")
    func removeHadithBookmarkByTextSource() {
        let id = UUID().uuidString.prefix(8)
        let text = "CM remove me \(id)"
        let source = "CMRemoveSource\(id)"
        let bookmark = BookmarkedHadith(text: text, source: source, narrator: "", grade: "Sahih")
        cache.saveHadithBookmark(bookmark)
        #expect(cache.isHadithBookmarked(text: text, source: source) == true)
        cache.removeHadithBookmark(text: text, source: source)
        #expect(cache.isHadithBookmarked(text: text, source: source) == false)
    }
}

@Suite("CacheManager - Journal", .serialized)
struct CacheManagerJournalTests {
    let cache = CacheManager.shared

    @Test("Save and load journal entry")
    func saveAndLoadJournalEntry() {
        let entry = JournalEntry(text: "CacheTest reflection")
        cache.saveJournalEntry(entry)
        defer { cache.removeJournalEntry(id: entry.id) }
        let loaded = cache.loadJournalEntries()
        #expect(loaded.contains { $0.id == entry.id })
    }

    @Test("Update journal entry text")
    func updateJournalEntry() {
        var entry = JournalEntry(text: "CacheTest original text")
        cache.saveJournalEntry(entry)
        defer { cache.removeJournalEntry(id: entry.id) }
        entry.text = "CacheTest updated text"
        cache.updateJournalEntry(entry)
        let found = cache.loadJournalEntries().first { $0.id == entry.id }
        #expect(found?.text == "CacheTest updated text")
    }

    @Test("Delete journal entry")
    func deleteJournalEntry() {
        let entry = JournalEntry(text: "CacheTest delete me")
        cache.saveJournalEntry(entry)
        cache.removeJournalEntry(id: entry.id)
        let loaded = cache.loadJournalEntries()
        #expect(!loaded.contains { $0.id == entry.id })
    }

    @Test("Journal entry with linked ayah persists")
    func journalWithLinkedAyah() {
        let linked = LinkedAyah(
            surahNumber: 505, surahName: "CacheTest-Baqarah",
            ayahNumber: 255, arabicText: "اللَّهُ",
            translationText: "Allah"
        )
        let entry = JournalEntry(text: "CacheTest ayat reflection", linkedAyah: linked)
        cache.saveJournalEntry(entry)
        defer { cache.removeJournalEntry(id: entry.id) }
        let loaded = cache.loadJournalEntries().first { $0.id == entry.id }
        #expect(loaded?.linkedAyah?.surahNumber == 505)
    }

    @Test("Journal entry with linked hadith persists")
    func journalWithLinkedHadith() {
        let linked = LinkedHadith(text: "CacheTest actions", source: "CacheTestBukhari")
        let entry = JournalEntry(text: "CacheTest niyyah", linkedHadith: linked)
        cache.saveJournalEntry(entry)
        defer { cache.removeJournalEntry(id: entry.id) }
        let loaded = cache.loadJournalEntries().first { $0.id == entry.id }
        #expect(loaded?.linkedHadith?.source == "CacheTestBukhari")
    }
}
