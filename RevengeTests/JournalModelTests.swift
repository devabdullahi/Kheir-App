import Testing
import Foundation
@testable import Revenge

@Suite("Journal Entry Model & Persistence", .serialized)
struct JournalModelTests {
    let cache = CacheManager.shared

    @Test("JournalEntry initializes with correct defaults")
    func journalEntryDefaults() {
        let entry = JournalEntry(text: "Hello world")
        #expect(!entry.id.uuidString.isEmpty)
        #expect(entry.text == "Hello world")
        #expect(entry.linkedAyah == nil)
        #expect(entry.linkedHadith == nil)
        #expect(entry.date.timeIntervalSinceNow < 1)
    }

    @Test("JournalEntry encodes and decodes correctly")
    func journalEncodeDecode() throws {
        let ayah = LinkedAyah(
            surahNumber: 36, surahName: "Ya-Sin",
            ayahNumber: 1, arabicText: "يس", translationText: "Ya, Sin."
        )
        let hadith = LinkedHadith(text: "Test hadith", source: "TestSource")
        let entry = JournalEntry(text: "Reflection", linkedAyah: ayah, linkedHadith: hadith)

        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(JournalEntry.self, from: data)

        #expect(decoded.id == entry.id)
        #expect(decoded.text == "Reflection")
        #expect(decoded.linkedAyah?.surahNumber == 36)
        #expect(decoded.linkedHadith?.source == "TestSource")
    }

    @Test("LinkedAyah equality works")
    func linkedAyahEquality() {
        let a = LinkedAyah(surahNumber: 1, surahName: "Al-Fatiha", ayahNumber: 1, arabicText: "a", translationText: "b")
        let b = LinkedAyah(surahNumber: 1, surahName: "Al-Fatiha", ayahNumber: 1, arabicText: "a", translationText: "b")
        let c = LinkedAyah(surahNumber: 2, surahName: "Al-Baqarah", ayahNumber: 1, arabicText: "a", translationText: "b")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("LinkedHadith equality works")
    func linkedHadithEquality() {
        let a = LinkedHadith(text: "text", source: "source")
        let b = LinkedHadith(text: "text", source: "source")
        let c = LinkedHadith(text: "other", source: "source")
        #expect(a == b)
        #expect(a != c)
    }

    @Test("Multiple journal entries persist in order")
    func multipleEntriesOrder() {
        let e1 = JournalEntry(text: "First entry test_order_1")
        let e2 = JournalEntry(text: "Second entry test_order_2")
        cache.saveJournalEntry(e1)
        cache.saveJournalEntry(e2)

        let loaded = cache.loadJournalEntries()
        let idx1 = loaded.firstIndex { $0.id == e1.id }
        let idx2 = loaded.firstIndex { $0.id == e2.id }
        // Newest (e2) should be before oldest (e1)
        if let i1 = idx1, let i2 = idx2 {
            #expect(i2 < i1)
        }

        cache.removeJournalEntry(id: e1.id)
        cache.removeJournalEntry(id: e2.id)
    }

    @Test("Update preserves entry position")
    func updatePreservesPosition() {
        // Use a unique ID prefix to avoid cross-suite interference
        let uniqueText = "Position test original \(UUID().uuidString)"
        var entry = JournalEntry(text: uniqueText)
        cache.saveJournalEntry(entry)
        defer { cache.removeJournalEntry(id: entry.id) }

        // Verify save succeeded before proceeding
        let afterSave = cache.loadJournalEntries()
        guard let originalIndex = afterSave.firstIndex(where: { $0.id == entry.id }) else {
            Issue.record("Entry not found after save")
            return
        }

        entry.text = "Position test updated \(entry.id.uuidString)"
        cache.updateJournalEntry(entry)

        let afterUpdate = cache.loadJournalEntries()
        let updatedIndex = afterUpdate.firstIndex { $0.id == entry.id }
        #expect(originalIndex == updatedIndex)

        let found = afterUpdate.first { $0.id == entry.id }
        #expect(found?.text == entry.text)
    }
}
