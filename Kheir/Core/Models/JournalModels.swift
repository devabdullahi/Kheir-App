import Foundation

struct JournalEntry: Codable, Identifiable, Sendable {
    let id: UUID
    var text: String
    var date: Date
    var linkedAyah: LinkedAyah?
    var linkedHadith: LinkedHadith?

    init(text: String, linkedAyah: LinkedAyah? = nil, linkedHadith: LinkedHadith? = nil) {
        self.id = UUID()
        self.text = text
        self.date = Date()
        self.linkedAyah = linkedAyah
        self.linkedHadith = linkedHadith
    }
}

struct LinkedAyah: Codable, Equatable, Sendable {
    let surahNumber: Int
    let surahName: String
    let ayahNumber: Int
    let arabicText: String
    let translationText: String
}

struct LinkedHadith: Codable, Equatable, Sendable {
    let text: String
    let source: String
}
