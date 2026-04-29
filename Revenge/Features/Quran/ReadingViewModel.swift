import Foundation
import Combine
import SwiftUI
import os

@MainActor
final class ReadingViewModel: ObservableObject {
    @Published var displayAyahs: [DisplayAyah] = []
    @Published var surahName: String = ""
    @Published var surahEnglishName: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    let surahNumber: Int
    let scrollToAyah: Int?

    private let cache = CacheManager.shared
    private let api = APIService.shared
    let audioPlayer = AudioPlayerService.shared
    private var savePositionTask: Task<Void, Never>?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "ReadingViewModel")

    init(surahNumber: Int, scrollToAyah: Int? = nil) {
        self.surahNumber = surahNumber
        self.scrollToAyah = scrollToAyah
    }

    func onAppear() {
        if let cached = cache.loadCachedSurah(surahNumber) {
            buildDisplay(arabic: cached.arabicAyahs, translation: cached.translationAyahs, transliteration: cached.transliterationAyahs)
        }
        loadBookmarkStates()
        Task { await fetchSurah() }
    }

    private func fetchSurah() async {
        isLoading = displayAyahs.isEmpty
        errorMessage = nil
        do {        
            let edition = AppSettings.shared.translationLanguage.rawValue
            async let arabicTask = api.fetchSurah(number: surahNumber, edition: "quran-uthmani")
            async let translationTask = api.fetchSurahTranslation(number: surahNumber, edition: edition)

            let arabic = try await arabicTask
            let translation = try await translationTask

            surahName = arabic.name
            surahEnglishName = arabic.englishName

            var transliteration: [Ayah]? = nil
            if AppSettings.shared.showTransliteration {
                if let translit = try? await api.fetchSurahTranslation(number: surahNumber, edition: "en.transliteration") {
                    transliteration = translit.ayahs
                }
            }

            buildDisplay(arabic: arabic.ayahs, translation: translation.ayahs, transliteration: transliteration)

            let cached = CachedSurah(
                surahNumber: surahNumber,
                arabicAyahs: arabic.ayahs,
                translationAyahs: translation.ayahs,
                transliterationAyahs: transliteration,
                cachedDate: Date()
            )
            cache.cacheSurah(cached)

            audioPlayer.configure(surah: surahNumber, totalAyahs: arabic.ayahs.count)
        } catch {
            logger.error("Failed to fetch surah \(self.surahNumber): \(error.localizedDescription)")
            if displayAyahs.isEmpty {
                errorMessage = "Unable to load surah. Please check your connection and try again."
            }
        }
        isLoading = false
    }

    func retry() {
        Task { await fetchSurah() }
    }

    private func buildDisplay(arabic: [Ayah], translation: [Ayah], transliteration: [Ayah]?) {
        displayAyahs = arabic.enumerated().map { index, arabicAyah in
            DisplayAyah(
                id: arabicAyah.number,
                numberInSurah: arabicAyah.numberInSurah,
                arabicText: arabicAyah.text,
                translationText: index < translation.count ? translation[index].text : "",
                transliteration: transliteration.flatMap { index < $0.count ? $0[index].text : nil } ?? "",
                audioURL: {
                    let q = Qari.resolve(AppSettings.shared.selectedQari)
                    return api.audioURL(qari: q.identifier, surah: surahNumber, ayah: arabicAyah.numberInSurah, bitrate: q.bitrate)
                }()
            )
        }
    }

    func saveReadingPosition(ayah: Int) {
        savePositionTask?.cancel()
        savePositionTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            AppSettings.shared.lastReadSurah = surahNumber
            AppSettings.shared.lastReadAyah = ayah
        }
    }

    @Published var bookmarkedAyahs: Set<Int> = []

    func loadBookmarkStates() {
        let bookmarks = cache.loadAyahBookmarks()
        bookmarkedAyahs = Set(
            bookmarks
                .filter { $0.surahNumber == surahNumber }
                .map { $0.ayahNumber }
        )
    }

    func isAyahBookmarked(_ ayahNumber: Int) -> Bool {
        bookmarkedAyahs.contains(ayahNumber)
    }

    func toggleBookmark(_ ayah: DisplayAyah) {
        if bookmarkedAyahs.contains(ayah.numberInSurah) {
            cache.removeAyahBookmark(surah: surahNumber, ayah: ayah.numberInSurah)
            bookmarkedAyahs.remove(ayah.numberInSurah)
        } else {
            let bookmark = BookmarkedAyah(
                surahNumber: surahNumber,
                surahName: surahEnglishName,
                ayahNumber: ayah.numberInSurah,
                arabicText: ayah.arabicText,
                translationText: ayah.translationText
            )
            cache.saveAyahBookmark(bookmark)
            bookmarkedAyahs.insert(ayah.numberInSurah)
        }
    }

    func shareText(for ayah: DisplayAyah) -> String {
        """
        \(ayah.arabicText)

        \(ayah.translationText)

        - \(surahEnglishName) \(surahNumber):\(ayah.numberInSurah)
        """
    }

    func playFromAyah(_ ayah: DisplayAyah) {
        audioPlayer.currentAyahIndex = ayah.numberInSurah - 1
        audioPlayer.play(surah: surahNumber, ayah: ayah.numberInSurah)
    }
}
