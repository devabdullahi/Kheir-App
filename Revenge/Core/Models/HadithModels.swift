import Foundation

struct DailyHadith: Codable, Identifiable, Sendable {
    let id: UUID
    let text: String
    let arabicText: String
    let source: String
    let chapter: String
    let narrator: String
    let grade: String
    let dateString: String

    init(text: String, arabicText: String = "", source: String, chapter: String, narrator: String, grade: String, dateString: String) {
        self.id = UUID()
        self.text = text
        self.arabicText = arabicText
        self.source = source
        self.chapter = chapter
        self.narrator = narrator
        self.grade = grade
        self.dateString = dateString
    }
}

// MARK: - fawazahmed0/hadith-api Response Models

/// Response for a single hadith section: /editions/{edition}/{sectionNo}.json
struct HadithSectionResponse: Codable, Sendable {
    let metadata: HadithMetadata
    let hadiths: [HadithAPIEntry]
}

struct HadithMetadata: Codable, Sendable {
    let name: String
    let section: [String: String]?
    let sectionDetail: [String: HadithSectionDetail]?

    enum CodingKeys: String, CodingKey {
        case name
        case section
        case sectionDetail = "section_detail"
    }
}

struct HadithSectionDetail: Codable, Sendable {
    let hadithNumberFirst: Int
    let hadithNumberLast: Int

    enum CodingKeys: String, CodingKey {
        case hadithNumberFirst = "hadithnumber_first"
        case hadithNumberLast = "hadithnumber_last"
    }
}

struct HadithAPIEntry: Codable, Sendable {
    let hadithNumber: Int
    let arabicNumber: Int
    let text: String
    let grades: [HadithGradeEntry]
    let reference: HadithReference

    enum CodingKeys: String, CodingKey {
        case hadithNumber = "hadithnumber"
        case arabicNumber = "arabicnumber"
        case text
        case grades
        case reference
    }
}

struct HadithGradeEntry: Codable, Sendable {
    let name: String
    let grade: String
}

struct HadithReference: Codable, Sendable {
    let book: Int
    let hadith: Int
}

/// Edition info from /editions.json
struct HadithEditionInfo: Codable, Sendable {
    let name: String
    let book: String
    let author: String?
    let language: String
    let hasSections: Bool?
    let direction: String?
    let link: String?
    let linkmin: String?

    enum CodingKeys: String, CodingKey {
        case name, book, author, language
        case hasSections = "has_sections"
        case direction, link, linkmin
    }
}

// MARK: - Hadith Collection Mapping

enum HadithCollection: String, CaseIterable, Sendable {
    case bukhari = "eng-bukhari"
    case muslim = "eng-muslim"
    case abuDawud = "eng-abudawud"
    case tirmidhi = "eng-tirmidhi"
    case nasai = "eng-nasai"
    case ibnMajah = "eng-ibnmajah"

    var displayName: String {
        switch self {
        case .bukhari: return "Sahih al-Bukhari"
        case .muslim: return "Sahih Muslim"
        case .abuDawud: return "Sunan Abu Dawud"
        case .tirmidhi: return "Jami at-Tirmidhi"
        case .nasai: return "Sunan an-Nasai"
        case .ibnMajah: return "Sunan Ibn Majah"
        }
    }

    var arabicEdition: String {
        switch self {
        case .bukhari: return "ara-bukhari"
        case .muslim: return "ara-muslim"
        case .abuDawud: return "ara-abudawud"
        case .tirmidhi: return "ara-tirmidhi"
        case .nasai: return "ara-nasai"
        case .ibnMajah: return "ara-ibnmajah"
        }
    }

    /// Approximate total sections per collection
    var totalSections: Int {
        switch self {
        case .bukhari: return 97
        case .muslim: return 56
        case .abuDawud: return 43
        case .tirmidhi: return 49
        case .nasai: return 51
        case .ibnMajah: return 37
        }
    }
}
