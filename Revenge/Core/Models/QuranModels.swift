import Foundation

// MARK: - Surah List Response
struct SurahListResponse: Codable {
    let code: Int
    let status: String
    let data: [SurahInfo]
}

struct SurahInfo: Codable, Identifiable {
    let number: Int
    let name: String
    let englishName: String
    let englishNameTranslation: String
    let numberOfAyahs: Int
    let revelationType: String

    var id: Int { number }
}

// MARK: - Surah Detail Response
struct SurahDetailResponse: Codable {
    let code: Int
    let status: String
    let data: SurahDetail
}

struct SurahDetail: Codable {
    let number: Int
    let name: String
    let englishName: String
    let englishNameTranslation: String
    let revelationType: String
    let numberOfAyahs: Int
    let ayahs: [Ayah]
}

struct Ayah: Codable, Identifiable {
    let number: Int
    let text: String
    let numberInSurah: Int
    let juz: Int
    let page: Int
    let hizbQuarter: Int

    var id: Int { number }
}

// MARK: - Combined Ayah for display (Arabic + Translation)
struct DisplayAyah: Identifiable {
    let id: Int
    let numberInSurah: Int
    let arabicText: String
    let translationText: String
    let transliteration: String
    let audioURL: URL?
}

// MARK: - Edition Response
struct EditionResponse: Codable {
    let code: Int
    let status: String
    let data: [Edition]
}

struct Edition: Codable, Identifiable {
    let identifier: String
    let language: String
    let name: String
    let englishName: String
    let type: String

    var id: String { identifier }
}

// MARK: - Daily Ayah
struct DailyAyah: Codable, Identifiable {
    let id: UUID
    let surahNumber: Int
    let surahName: String
    let surahEnglishName: String
    let ayahNumber: Int
    let arabicText: String
    let translationText: String
    let transliteration: String
    let dateString: String

    init(surahNumber: Int, surahName: String, surahEnglishName: String, ayahNumber: Int, arabicText: String, translationText: String, transliteration: String, dateString: String) {
        self.id = UUID()
        self.surahNumber = surahNumber
        self.surahName = surahName
        self.surahEnglishName = surahEnglishName
        self.ayahNumber = ayahNumber
        self.arabicText = arabicText
        self.translationText = translationText
        self.transliteration = transliteration
        self.dateString = dateString
    }
}

// MARK: - Qari (Reciter)
struct Qari: Identifiable, Codable {
    let identifier: String
    let name: String
    /// CDN bitrate (kbps). Some reciters are only licensed at lower bitrates on cdn.islamic.network.
    let bitrate: Int

    var id: String { identifier }

    init(identifier: String, name: String, bitrate: Int = 128) {
        self.identifier = identifier
        self.name = name
        self.bitrate = bitrate
    }

    static let defaults: [Qari] = [
        Qari(identifier: "ar.alafasy", name: "Mishary Rashid Alafasy", bitrate: 128),
        Qari(identifier: "ar.abdurrahmaansudais", name: "Abdurrahmaan As-Sudais", bitrate: 64),
        Qari(identifier: "ar.abdulsamad", name: "Abdul Basit Abdus-Samad", bitrate: 64),
        Qari(identifier: "ar.husary", name: "Mahmoud Khalil Al-Husary", bitrate: 128),
        Qari(identifier: "ar.minshawi", name: "Mohamed Siddiq El-Minshawi", bitrate: 128)
    ]

    /// Looks up a default reciter by identifier. Falls back to Alafasy if unknown.
    static func resolve(_ identifier: String) -> Qari {
        defaults.first { $0.identifier == identifier } ?? defaults[0]
    }
}

// MARK: - Cached Surah
struct CachedSurah: Codable {
    let surahNumber: Int
    let arabicAyahs: [Ayah]
    let translationAyahs: [Ayah]
    let transliterationAyahs: [Ayah]?
    let cachedDate: Date
}
