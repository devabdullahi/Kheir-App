import Foundation

struct BookmarkedAyah: Codable, Identifiable, Sendable {
    let id: UUID
    let surahNumber: Int
    let surahName: String
    let ayahNumber: Int
    let arabicText: String
    let translationText: String
    let savedDate: Date

    init(surahNumber: Int, surahName: String, ayahNumber: Int, arabicText: String, translationText: String) {
        self.id = UUID()
        self.surahNumber = surahNumber
        self.surahName = surahName
        self.ayahNumber = ayahNumber
        self.arabicText = arabicText
        self.translationText = translationText
        self.savedDate = Date()
    }
}

struct BookmarkedHadith: Codable, Identifiable, Sendable {
    let id: UUID
    let text: String
    /// Empty when the hadith had no Arabic, and for bookmarks saved before it was kept.
    let arabicText: String
    let source: String
    let narrator: String
    let grade: String
    let savedDate: Date

    init(text: String, arabicText: String = "", source: String, narrator: String, grade: String) {
        self.id = UUID()
        self.text = text
        self.arabicText = arabicText
        self.source = source
        self.narrator = narrator
        self.grade = grade
        self.savedDate = Date()
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        arabicText = try c.decodeIfPresent(String.self, forKey: .arabicText) ?? ""
        source = try c.decode(String.self, forKey: .source)
        narrator = try c.decode(String.self, forKey: .narrator)
        grade = try c.decode(String.self, forKey: .grade)
        savedDate = try c.decode(Date.self, forKey: .savedDate)
    }
}
