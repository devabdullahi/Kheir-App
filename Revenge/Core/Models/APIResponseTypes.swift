import Foundation

// MARK: - Additional Response Types

struct AyahResponse: Codable {
    let code: Int
    let data: Ayah
}

struct AyahDetailResponse: Codable {
    let code: Int
    let data: AyahDetailData
}

struct AyahDetailData: Codable {
    let number: Int
    let text: String
    let numberInSurah: Int
    let surah: AyahSurahInfo

    struct AyahSurahInfo: Codable {
        let number: Int
        let name: String
        let englishName: String
        let englishNameTranslation: String
    }
}

struct HijriConvertResponse: Codable {
    let code: Int
    let data: HijriConvertData
}

struct HijriConvertData: Codable {
    let hijri: HijriDate
}
