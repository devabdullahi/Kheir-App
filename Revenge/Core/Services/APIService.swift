import Foundation

final class APIService: @unchecked Sendable {
    static let shared = APIService()
    private static let decoder = JSONDecoder()
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
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.serverError(statusCode: statusCode)
        }
        do {
            return try Self.decoder.decode(type, from: data)
        } catch let error as DecodingError {
            throw APIError.decodingError(underlying: error)
        }
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

    /// Fetch a hadith section using a raw edition string
    func fetchHadithSection(editionRaw: String, section: Int) async throws -> HadithSectionResponse {
        let urlStr = "\(AppConstants.hadithBaseURL)/editions/\(editionRaw)/sections/\(section).json"
        return try await fetch(HadithSectionResponse.self, from: urlStr)
    }

    /// Fetch a random daily hadith from a random major collection
    func fetchRandomHadith() async throws -> (entry: HadithAPIEntry, collection: HadithCollection, sectionName: String, section: Int) {
        // Pick a random collection and section for variety
        let collections: [HadithCollection] = [.bukhari, .muslim, .abuDawud, .tirmidhi, .nasai, .ibnMajah]
        guard let collection = collections.randomElement() else {
            throw APIError.serverError(statusCode: -1)
        }
        let section = Int.random(in: 1...collection.totalSections)

        let response = try await fetchHadithSection(edition: collection, section: section)

        guard !response.hadiths.isEmpty else {
            throw APIError.serverError(statusCode: -1)
        }

        guard let hadith = response.hadiths.randomElement() else {
            throw APIError.serverError(statusCode: -1)
        }
        let sectionName = response.metadata.section?["\(section)"] ?? "General"

        return (hadith, collection, sectionName, section)
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

// MARK: - Errors
enum APIError: LocalizedError {
    case invalidURL
    case serverError(statusCode: Int)
    case decodingError(underlying: DecodingError)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .serverError(let statusCode):
            return "Server error (HTTP \(statusCode))"
        case .decodingError(let underlying):
            return "Failed to decode response: \(underlying.localizedDescription)"
        }
    }
}
