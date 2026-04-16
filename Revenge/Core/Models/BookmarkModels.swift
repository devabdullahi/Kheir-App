import Foundation

struct BookmarkedAyah: Codable, Identifiable {
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

struct BookmarkedHadith: Codable, Identifiable {
    let id: UUID
    let text: String
    let source: String
    let narrator: String
    let grade: String
    let savedDate: Date

    init(text: String, source: String, narrator: String, grade: String) {
        self.id = UUID()
        self.text = text
        self.source = source
        self.narrator = narrator
        self.grade = grade
        self.savedDate = Date()
    }
}
