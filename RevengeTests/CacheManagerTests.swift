import Testing
import Foundation
@testable import Revenge

@Suite("CacheManager - Ayah Bookmarks", .serialized)
struct CacheManagerAyahTests {
    let cache = CacheManager.shared

    @Test("Save and load ayah bookmark")
    func saveAndLoadAyahBookmark() async {
        let bookmark = BookmarkedAyah(
            surahNumber: 501, surahName: "CacheTest-Fatiha",
            ayahNumber: 1, arabicText: "بِسْمِ اللَّهِ",
            translationText: "In the name of Allah"
        )
        await cache.saveAyahBookmark(bookmark)
        let loaded = await cache.loadAyahBookmarks()
        #expect(loaded.contains { $0.id == bookmark.id })
        await cache.removeAyahBookmark(id: bookmark.id)
    }

    @Test("isAyahBookmarked returns true for saved ayah")
    func isAyahBookmarkedTrue() async {
        let bookmark = BookmarkedAyah(
            surahNumber: 502, surahName: "CacheTest",
            ayahNumber: 42, arabicText: "test", translationText: "test"
        )
        await cache.saveAyahBookmark(bookmark)
        let result = await cache.isAyahBookmarked(surah: 502, ayah: 42)
        #expect(result == true)
        await cache.removeAyahBookmark(id: bookmark.id)
    }

    @Test("isAyahBookmarked returns false for unsaved ayah")
    func isAyahBookmarkedFalse() async {
        let result = await cache.isAyahBookmarked(surah: 503, ayah: 999)
        #expect(result == false)
    }

    @Test("Remove ayah bookmark by surah and ayah")
    func removeAyahBookmarkBySurahAyah() async {
        let bookmark = BookmarkedAyah(
            surahNumber: 504, surahName: "CacheTest",
            ayahNumber: 1, arabicText: "a", translationText: "b"
        )
        await cache.saveAyahBookmark(bookmark)
        let afterSave = await cache.isAyahBookmarked(surah: 504, ayah: 1)
        #expect(afterSave == true)
        await cache.removeAyahBookmark(surah: 504, ayah: 1)
        let afterRemove = await cache.isAyahBookmarked(surah: 504, ayah: 1)
        #expect(afterRemove == false)
    }
}

@Suite("CacheManager - Hadith Bookmarks", .serialized)
struct CacheManagerHadithTests {
    let cache = CacheManager.shared

    @Test("Save and load hadith bookmark")
    func saveAndLoadHadithBookmark() async {
        let id = UUID().uuidString.prefix(8)
        let bookmark = BookmarkedHadith(
            text: "CM hadith \(id)",
            source: "CMSource\(id)", narrator: "TestNarrator", grade: "Sahih"
        )
        await cache.saveHadithBookmark(bookmark)
        let loaded = await cache.loadHadithBookmarks()
        #expect(loaded.contains { $0.id == bookmark.id })
        await cache.removeHadithBookmark(id: bookmark.id)
    }

    @Test("isHadithBookmarked works correctly")
    func isHadithBookmarked() async {
        let id = UUID().uuidString.prefix(8)
        let text = "CM unique hadith \(id)"
        let source = "CMUniqueSource\(id)"
        let bookmark = BookmarkedHadith(text: text, source: source, narrator: "", grade: "Hasan")
        await cache.saveHadithBookmark(bookmark)
        let isBookmarked = await cache.isHadithBookmarked(text: text, source: source)
        #expect(isBookmarked == true)
        let isNotBookmarked = await cache.isHadithBookmarked(text: "nonexistent_\(id)", source: "nowhere_\(id)")
        #expect(isNotBookmarked == false)
        await cache.removeHadithBookmark(id: bookmark.id)
    }

    @Test("Remove hadith bookmark by text and source")
    func removeHadithBookmarkByTextSource() async {
        let id = UUID().uuidString.prefix(8)
        let text = "CM remove me \(id)"
        let source = "CMRemoveSource\(id)"
        let bookmark = BookmarkedHadith(text: text, source: source, narrator: "", grade: "Sahih")
        await cache.saveHadithBookmark(bookmark)
        let afterSave = await cache.isHadithBookmarked(text: text, source: source)
        #expect(afterSave == true)
        await cache.removeHadithBookmark(text: text, source: source)
        let afterRemove = await cache.isHadithBookmarked(text: text, source: source)
        #expect(afterRemove == false)
    }
}

@Suite("CacheManager - Journal", .serialized)
struct CacheManagerJournalTests {
    let cache = CacheManager.shared

    @Test("Save and load journal entry")
    func saveAndLoadJournalEntry() async {
        let entry = JournalEntry(text: "CacheTest reflection")
        await cache.saveJournalEntry(entry)
        let loaded = await cache.loadJournalEntries()
        #expect(loaded.contains { $0.id == entry.id })
        await cache.removeJournalEntry(id: entry.id)
    }

    @Test("Update journal entry text")
    func updateJournalEntry() async {
        var entry = JournalEntry(text: "CacheTest original text")
        await cache.saveJournalEntry(entry)
        entry.text = "CacheTest updated text"
        await cache.updateJournalEntry(entry)
        let found = await cache.loadJournalEntries().first { $0.id == entry.id }
        #expect(found?.text == "CacheTest updated text")
        await cache.removeJournalEntry(id: entry.id)
    }

    @Test("Delete journal entry")
    func deleteJournalEntry() async {
        let entry = JournalEntry(text: "CacheTest delete me")
        await cache.saveJournalEntry(entry)
        await cache.removeJournalEntry(id: entry.id)
        let loaded = await cache.loadJournalEntries()
        #expect(!loaded.contains { $0.id == entry.id })
    }

    @Test("Journal entry with linked ayah persists")
    func journalWithLinkedAyah() async {
        let linked = LinkedAyah(
            surahNumber: 505, surahName: "CacheTest-Baqarah",
            ayahNumber: 255, arabicText: "اللَّهُ",
            translationText: "Allah"
        )
        let entry = JournalEntry(text: "CacheTest ayat reflection", linkedAyah: linked)
        await cache.saveJournalEntry(entry)
        let loaded = await cache.loadJournalEntries().first { $0.id == entry.id }
        #expect(loaded?.linkedAyah?.surahNumber == 505)
        await cache.removeJournalEntry(id: entry.id)
    }

    @Test("Journal entry with linked hadith persists")
    func journalWithLinkedHadith() async {
        let linked = LinkedHadith(text: "CacheTest actions", source: "CacheTestBukhari")
        let entry = JournalEntry(text: "CacheTest niyyah", linkedHadith: linked)
        await cache.saveJournalEntry(entry)
        let loaded = await cache.loadJournalEntries().first { $0.id == entry.id }
        #expect(loaded?.linkedHadith?.source == "CacheTestBukhari")
        await cache.removeJournalEntry(id: entry.id)
    }
}
