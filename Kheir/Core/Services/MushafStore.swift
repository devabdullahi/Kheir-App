import Foundation
import os

/// Loads Madani mushaf pages from quran.com (word-by-word with line numbers) and
/// keeps every page it has seen on disk, so a page read once opens offline.
actor MushafStore {
    static let shared = MushafStore()

    /// PostScript name of the bundled Amiri Quran font (SIL Open Font License).
    nonisolated static let fontName = "AmiriQuran-Regular"

    private let session: URLSession
    private let directory: URL
    private var memory: [Int: MushafPage] = [:]
    private var inFlight: [Int: Task<MushafPage, Error>] = [:]
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "MushafStore")

    init(session: URLSession = .shared) {
        self.session = session
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = caches.appendingPathComponent("Mushaf/v1", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    /// A page already in memory or on disk, without touching the network.
    func cachedPage(_ number: Int) -> MushafPage? {
        if let page = memory[number] { return page }
        guard let data = try? Data(contentsOf: fileURL(number)),
              let page = try? JSONDecoder().decode(MushafPage.self, from: data) else { return nil }
        memory[number] = page
        return page
    }

    func page(_ number: Int) async throws -> MushafPage {
        if let page = cachedPage(number) { return page }
        if let task = inFlight[number] { return try await task.value }

        let task = Task { try await download(number) }
        inFlight[number] = task
        defer { inFlight[number] = nil }

        let page = try await task.value
        memory[number] = page
        if let data = try? JSONEncoder().encode(page) {
            try? data.write(to: fileURL(number), options: .atomic)
        }
        return page
    }

    /// Fetches the pages either side in the background so a turn never waits.
    func prefetch(around number: Int) {
        for n in [number + 1, number - 1, number + 2] where (1...MushafPage.count).contains(n) && cachedPage(n) == nil {
            Task { _ = try? await page(n) }
        }
    }

    private func fileURL(_ number: Int) -> URL {
        directory.appendingPathComponent(String(format: "page-%03d.json", number))
    }

    private func download(_ number: Int) async throws -> MushafPage {
        let url = URL(string: "https://api.quran.com/api/v4/verses/by_page/\(number)?words=true&word_fields=line_number,text_uthmani&fields=chapter_id&per_page=50&mushaf=1")!
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw APIError.serverError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        let decoded = try JSONDecoder().decode(QuranComPage.self, from: data)
        return Self.layout(number: number, verses: decoded.verses)
    }

    /// Places each word on its printed line. Lines with no words are the surah
    /// banner and bismillah before a surah's first ayah.
    static func layout(number: Int, verses: [QuranComPage.Verse]) -> MushafPage {
        var byLine: [Int: [MushafWord]] = [:]
        var firstLineOfSurah: [Int: Int] = [:]
        for verse in verses {
            for word in verse.words {
                guard let line = word.lineNumber else { continue }
                byLine[line, default: []].append(MushafWord(
                    text: word.textUthmani,
                    surah: verse.chapterId,
                    ayah: verse.verseNumber,
                    isAyahEnd: word.charTypeName == "end"
                ))
                if verse.verseNumber == 1 {
                    firstLineOfSurah[verse.chapterId] = min(firstLineOfSurah[verse.chapterId] ?? .max, line)
                }
            }
        }

        // Every page has 15 lines except the opening two, which are shorter.
        let lineCount = number <= 2 ? (byLine.keys.max() ?? 8) : 15
        // A surah opens with its banner, then the bismillah (except al-Fatihah,
        // where it is the first ayah, and at-Tawbah, which has none).
        func opening(_ surah: Int) -> [MushafLine.Kind] {
            surah == 1 || surah == 9 ? [.banner] : [.banner, .bismillah]
        }
        var kinds: [Int: (MushafLine.Kind, Int)] = [:]
        for (surah, first) in firstLineOfSurah {
            // Fill the empty lines just above the first ayah from the bottom up.
            // Any that don't fit sit at the foot of the previous page.
            let empty = (1..<first).reversed().prefix { byLine[$0] == nil }
            for (line, kind) in zip(empty, opening(surah).reversed()) {
                kinds[line] = (kind, surah)
            }
        }
        // Empty lines at the foot of the page hold the start of the next surah.
        if number > 2, let lastSurah = verses.last?.chapterId, lastSurah < 114,
           let lastLine = byLine.keys.max(), lastLine < lineCount {
            for (line, kind) in zip((lastLine + 1)...lineCount, opening(lastSurah + 1)) {
                kinds[line] = (kind, lastSurah + 1)
            }
        }

        let lines = (1...lineCount).map { n -> MushafLine in
            if let words = byLine[n] { return MushafLine(id: n, kind: .text, words: words) }
            if let (kind, surah) = kinds[n] { return MushafLine(id: n, kind: kind, surah: surah) }
            return MushafLine(id: n, kind: .blank)
        }
        let first = verses.first
        return MushafPage(
            number: number,
            juz: first?.juzNumber ?? 1,
            hizb: first?.hizbNumber ?? 1,
            surah: first?.chapterId ?? MushafIndex.surah(onPage: number),
            lines: lines
        )
    }
}

// MARK: - quran.com v4 response

struct QuranComPage: Decodable, Sendable {
    let verses: [Verse]

    struct Verse: Decodable, Sendable {
        let verseNumber: Int
        let chapterId: Int
        let juzNumber: Int
        let hizbNumber: Int
        let words: [Word]

        enum CodingKeys: String, CodingKey {
            case verseNumber = "verse_number", chapterId = "chapter_id"
            case juzNumber = "juz_number", hizbNumber = "hizb_number", words
        }
    }

    struct Word: Decodable, Sendable {
        let charTypeName: String
        let lineNumber: Int?
        let textUthmani: String

        enum CodingKeys: String, CodingKey {
            case charTypeName = "char_type_name", lineNumber = "line_number", textUthmani = "text_uthmani"
        }
    }
}
