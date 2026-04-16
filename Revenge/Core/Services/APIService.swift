import Foundation

final class APIService: @unchecked Sendable {
    static let shared = APIService()
    private let session: URLSession

    private init() {
        let cache = URLCache(
            memoryCapacity: 10 * 1024 * 1024,   // 10 MB
            diskCapacity:   50 * 1024 * 1024,    // 50 MB
            diskPath: "api_service_cache"
        )
        let config = URLSessionConfiguration.default
        config.urlCache = cache
        config.requestCachePolicy = .useProtocolCachePolicy
        config.timeoutIntervalForRequest  = 15   // seconds until a connection is established
        config.timeoutIntervalForResource = 30   // seconds for the full resource transfer
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }

    // MARK: - Generic Fetch
    private func fetch<T: Decodable>(_ type: T.Type, from urlString: String) async throws -> T {
        guard let url = URL(string: urlString) else {
            throw APIError.invalidURL
        }
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw APIError.serverError
        }
        return try JSONDecoder().decode(type, from: data)
    }

    // MARK: - Surah List
    func fetchSurahList() async throws -> [SurahInfo] {
        let response = try await fetch(SurahListResponse.self, from: "\(AppConstants.quranBaseURL)/surah")
        return response.data
    }

    // MARK: - Surah Detail (Arabic)
    func fetchSurah(number: Int, edition: String = "quran-uthmani") async throws -> SurahDetail {
        let response = try await fetch(SurahDetailResponse.self, from: "\(AppConstants.quranBaseURL)/surah/\(number)/\(edition)")
        return response.data
    }

    // MARK: - Surah Translation
    func fetchSurahTranslation(number: Int, edition: String) async throws -> SurahDetail {
        let response = try await fetch(SurahDetailResponse.self, from: "\(AppConstants.quranBaseURL)/surah/\(number)/\(edition)")
        return response.data
    }

    // MARK: - Random Ayah (for Daily Ayah)
    func fetchRandomAyah(edition: String = "quran-uthmani") async throws -> Ayah {
        let randomAyah = Int.random(in: 1...6236)
        let response = try await fetch(AyahResponse.self, from: "\(AppConstants.quranBaseURL)/ayah/\(randomAyah)/\(edition)")
        return response.data
    }

    func fetchAyahTranslation(number: Int, edition: String) async throws -> AyahDetailData {
        let response = try await fetch(AyahDetailResponse.self, from: "\(AppConstants.quranBaseURL)/ayah/\(number)/\(edition)")
        return response.data
    }

    // MARK: - Prayer Times (Aladhan fallback)
    func fetchPrayerTimes(latitude: Double, longitude: Double, method: Int = 2) async throws -> AladhanData {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let dateStr = dateFormatter.string(from: Date())
        let urlStr = "\(AppConstants.aladhanBaseURL)/timings/\(dateStr)?latitude=\(latitude)&longitude=\(longitude)&method=\(method)"
        let response = try await fetch(AladhanResponse.self, from: urlStr)
        return response.data
    }

    // MARK: - Hijri Date
    func fetchHijriDate() async throws -> HijriDate {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd-MM-yyyy"
        let dateStr = dateFormatter.string(from: Date())
        let urlStr = "\(AppConstants.aladhanBaseURL)/gpiToH/\(dateStr)"
        let response = try await fetch(HijriConvertResponse.self, from: urlStr)
        return response.data.hijri
    }

    // MARK: - Hadith (fawazahmed0/hadith-api)

    /// Fetch a section of hadiths from a specific collection
    func fetchHadithSection(edition: HadithCollection, section: Int) async throws -> HadithSectionResponse {
        let urlStr = "\(AppConstants.hadithBaseURL)/editions/\(edition.rawValue)/sections/\(section).json"
        return try await fetch(HadithSectionResponse.self, from: urlStr)
    }

    /// Fetch a single hadith by number from a collection
    func fetchHadith(edition: HadithCollection, number: Int) async throws -> HadithSectionResponse {
        let urlStr = "\(AppConstants.hadithBaseURL)/editions/\(edition.rawValue)/\(number).json"
        return try await fetch(HadithSectionResponse.self, from: urlStr)
    }

    /// Fetch a random daily hadith from a random major collection
    func fetchRandomHadith() async throws -> (entry: HadithAPIEntry, collection: HadithCollection, sectionName: String) {
        // Pick a random collection and section for variety
        let collections: [HadithCollection] = [.bukhari, .muslim, .abuDawud, .tirmidhi, .nasai, .ibnMajah]
        let collection = collections.randomElement()!
        let section = Int.random(in: 1...collection.totalSections)

        let response = try await fetchHadithSection(edition: collection, section: section)

        guard !response.hadiths.isEmpty else {
            throw APIError.serverError
        }

        let hadith = response.hadiths.randomElement()!
        let sectionName = response.metadata.section?["\(section)"] ?? "General"

        return (hadith, collection, sectionName)
    }

    // MARK: - Audio URL
    /// Builds a streaming URL for a single ayah from the Islamic Network CDN.
    /// The CDN uses a GLOBAL ayah index (1-6236), not surah+ayah. This helper
    /// translates a (surah, ayahInSurah) pair into the global index.
    /// Bitrate is per-reciter: some editions are only licensed at 64kbps on the CDN.
    func audioURL(qari: String, surah: Int, ayah: Int, bitrate: Int = 128) -> URL? {
        guard let globalIndex = QuranAyahIndex.globalIndex(surah: surah, ayahInSurah: ayah) else {
            return nil
        }
        return URL(string: "\(AppConstants.audioBaseURL)/\(bitrate)/\(qari)/\(globalIndex).mp3")
    }
}

// MARK: - Quran Ayah Global Index

/// Maps (surah, ayahInSurah) → global ayah number (1...6236) using the canonical
/// 114-surah ayah count table. Used by cdn.islamic.network audio URL construction.
enum QuranAyahIndex {
    /// Number of ayahs in each surah, index 0 = Surah 1 (Al-Fatiha).
    static let ayahCounts: [Int] = [
        7, 286, 200, 176, 120, 165, 206, 75, 129, 109,
        123, 111, 43, 52, 99, 128, 111, 110, 98, 135,
        112, 78, 118, 64, 77, 227, 93, 88, 69, 60,
        34, 30, 73, 54, 45, 83, 182, 88, 75, 85,
        54, 53, 89, 59, 37, 35, 38, 29, 18, 45,
        60, 49, 62, 55, 78, 96, 29, 22, 24, 13,
        14, 11, 11, 18, 12, 12, 30, 52, 52, 44,
        28, 28, 20, 56, 40, 31, 50, 40, 46, 42,
        29, 19, 36, 25, 22, 17, 19, 26, 30, 20,
        15, 21, 11, 8, 8, 19, 5, 8, 8, 11,
        11, 8, 3, 9, 5, 4, 7, 3, 6, 3,
        5, 4, 5, 6
    ]

    /// Prefix sums over `ayahCounts` so that `prefixSums[i]` is the total number
    /// of ayahs before surah `i + 1` (0-indexed). Computed once at app launch; each
    /// lookup is then O(1) instead of O(n).
    static let prefixSums: [Int] = {
        var sums = [Int](repeating: 0, count: ayahCounts.count)
        var running = 0
        for i in ayahCounts.indices {
            sums[i] = running
            running += ayahCounts[i]
        }
        return sums
    }()

    /// Returns the 1-based global ayah number for a given surah (1-114) and
    /// ayah-within-surah (1-based). Returns nil if either value is out of range.
    /// Complexity: O(1) via precomputed prefix sums.
    static func globalIndex(surah: Int, ayahInSurah: Int) -> Int? {
        guard surah >= 1, surah <= 114 else { return nil }
        let count = ayahCounts[surah - 1]
        guard ayahInSurah >= 1, ayahInSurah <= count else { return nil }
        return prefixSums[surah - 1] + ayahInSurah
    }
}

// MARK: - Errors
enum APIError: LocalizedError {
    case invalidURL
    case serverError
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .serverError: return "Server error"
        case .decodingError: return "Failed to decode response"
        }
    }
}

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
