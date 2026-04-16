import Testing
import Foundation
@testable import Revenge

@Suite("Bookmark Toggling Logic", .serialized)
struct BookmarkToggleTests {
    let cache = CacheManager.shared

    @Test("Ayah toggle: add then remove")
    func ayahToggleAddRemove() {
        let surah = 701
        let ayahNum = 6
        cache.removeAyahBookmark(surah: surah, ayah: ayahNum)
        #expect(cache.isAyahBookmarked(surah: surah, ayah: ayahNum) == false)

        let bookmark = BookmarkedAyah(
            surahNumber: surah, surahName: "ToggleTest-Nas",
            ayahNumber: ayahNum, arabicText: "text", translationText: "text"
        )
        cache.saveAyahBookmark(bookmark)
        #expect(cache.isAyahBookmarked(surah: surah, ayah: ayahNum) == true)

        cache.removeAyahBookmark(surah: surah, ayah: ayahNum)
        #expect(cache.isAyahBookmarked(surah: surah, ayah: ayahNum) == false)
    }

    @Test("Hadith toggle: add then remove")
    func hadithToggleAddRemove() {
        let id = UUID().uuidString.prefix(8)
        let text = "Toggle hadith \(id)"
        let source = "ToggleSource\(id)"

        #expect(cache.isHadithBookmarked(text: text, source: source) == false)

        let bookmark = BookmarkedHadith(text: text, source: source, narrator: "", grade: "Sahih")
        cache.saveHadithBookmark(bookmark)
        #expect(cache.isHadithBookmarked(text: text, source: source) == true)

        cache.removeHadithBookmark(text: text, source: source)
        #expect(cache.isHadithBookmarked(text: text, source: source) == false)
    }

    @Test("Rapid ayah toggle does not duplicate")
    func rapidAyahToggle() {
        let surah = 702
        let ayahNum = 1
        cache.removeAyahBookmark(surah: surah, ayah: ayahNum)

        let b1 = BookmarkedAyah(surahNumber: surah, surahName: "ToggleTest", ayahNumber: ayahNum, arabicText: "a", translationText: "b")
        cache.saveAyahBookmark(b1)
        cache.removeAyahBookmark(surah: surah, ayah: ayahNum)
        let b2 = BookmarkedAyah(surahNumber: surah, surahName: "ToggleTest", ayahNumber: ayahNum, arabicText: "a", translationText: "b")
        cache.saveAyahBookmark(b2)

        let bookmarks = cache.loadAyahBookmarks().filter { $0.surahNumber == surah && $0.ayahNumber == ayahNum }
        #expect(bookmarks.count == 1)

        cache.removeAyahBookmark(surah: surah, ayah: ayahNum)
    }

    @Test("Rapid hadith toggle does not duplicate")
    func rapidHadithToggle() {
        let id = UUID().uuidString.prefix(8)
        let text = "Rapid toggle \(id)"
        let source = "RapidSource\(id)"

        let b1 = BookmarkedHadith(text: text, source: source, narrator: "", grade: "Hasan")
        cache.saveHadithBookmark(b1)
        cache.removeHadithBookmark(text: text, source: source)
        let b2 = BookmarkedHadith(text: text, source: source, narrator: "", grade: "Hasan")
        cache.saveHadithBookmark(b2)

        let bookmarks = cache.loadHadithBookmarks().filter { $0.text == text && $0.source == source }
        #expect(bookmarks.count == 1)

        cache.removeHadithBookmark(text: text, source: source)
    }

    @Test("Removing non-existent bookmark is safe")
    func removeNonexistentBookmark() {
        cache.removeAyahBookmark(surah: 0, ayah: 0)
        cache.removeHadithBookmark(text: "toggletest_nonexistent", source: "nowhere")
        #expect(true)
    }
}
