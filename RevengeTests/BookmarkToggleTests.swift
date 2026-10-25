import Testing
import Foundation
@testable import Revenge

@Suite("Bookmark Toggling Logic", .serialized)
struct BookmarkToggleTests {
    let cache = CacheManager.shared

    @Test("Ayah toggle: add then remove")
    func ayahToggleAddRemove() async {
        let surah = 701
        let ayahNum = 6
        await cache.removeAyahBookmark(surah: surah, ayah: ayahNum)
        let initial = await cache.isAyahBookmarked(surah: surah, ayah: ayahNum)
        #expect(initial == false)

        let bookmark = BookmarkedAyah(
            surahNumber: surah, surahName: "ToggleTest-Nas",
            ayahNumber: ayahNum, arabicText: "text", translationText: "text"
        )
        await cache.saveAyahBookmark(bookmark)
        let afterSave = await cache.isAyahBookmarked(surah: surah, ayah: ayahNum)
        #expect(afterSave == true)

        await cache.removeAyahBookmark(surah: surah, ayah: ayahNum)
        let afterRemove = await cache.isAyahBookmarked(surah: surah, ayah: ayahNum)
        #expect(afterRemove == false)
    }

    @Test("Hadith toggle: add then remove")
    func hadithToggleAddRemove() async {
        let id = UUID().uuidString.prefix(8)
        let text = "Toggle hadith \(id)"
        let source = "ToggleSource\(id)"

        let initial = await cache.isHadithBookmarked(text: text, source: source)
        #expect(initial == false)

        let bookmark = BookmarkedHadith(text: text, source: source, narrator: "", grade: "Sahih")
        await cache.saveHadithBookmark(bookmark)
        let afterSave = await cache.isHadithBookmarked(text: text, source: source)
        #expect(afterSave == true)

        await cache.removeHadithBookmark(text: text, source: source)
        let afterRemove = await cache.isHadithBookmarked(text: text, source: source)
        #expect(afterRemove == false)
    }

    @Test("Rapid ayah toggle does not duplicate")
    func rapidAyahToggle() async {
        let surah = 702
        let ayahNum = 1
        await cache.removeAyahBookmark(surah: surah, ayah: ayahNum)

        let b1 = BookmarkedAyah(surahNumber: surah, surahName: "ToggleTest", ayahNumber: ayahNum, arabicText: "a", translationText: "b")
        await cache.saveAyahBookmark(b1)
        await cache.removeAyahBookmark(surah: surah, ayah: ayahNum)
        let b2 = BookmarkedAyah(surahNumber: surah, surahName: "ToggleTest", ayahNumber: ayahNum, arabicText: "a", translationText: "b")
        await cache.saveAyahBookmark(b2)

        let bookmarks = await cache.loadAyahBookmarks().filter { $0.surahNumber == surah && $0.ayahNumber == ayahNum }
        #expect(bookmarks.count == 1)

        await cache.removeAyahBookmark(surah: surah, ayah: ayahNum)
    }

    @Test("Rapid hadith toggle does not duplicate")
    func rapidHadithToggle() async {
        let id = UUID().uuidString.prefix(8)
        let text = "Rapid toggle \(id)"
        let source = "RapidSource\(id)"

        let b1 = BookmarkedHadith(text: text, source: source, narrator: "", grade: "Hasan")
        await cache.saveHadithBookmark(b1)
        await cache.removeHadithBookmark(text: text, source: source)
        let b2 = BookmarkedHadith(text: text, source: source, narrator: "", grade: "Hasan")
        await cache.saveHadithBookmark(b2)

        let bookmarks = await cache.loadHadithBookmarks().filter { $0.text == text && $0.source == source }
        #expect(bookmarks.count == 1)

        await cache.removeHadithBookmark(text: text, source: source)
    }

    @Test("Removing non-existent bookmark is safe")
    func removeNonexistentBookmark() async {
        await cache.removeAyahBookmark(surah: 0, ayah: 0)
        await cache.removeHadithBookmark(text: "toggletest_nonexistent", source: "nowhere")
        #expect(true)
    }
}
