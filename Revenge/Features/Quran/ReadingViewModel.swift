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

    private let cache: any CacheManaging
    private let api: APIService
    let audioPlayer: AudioPlayerService
    private let settings: AppSettings
    private var savePositionTask: Task<Void, Never>?
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "ReadingViewModel")

    init(
        surahNumber: Int,
        scrollToAyah: Int? = nil,
        cache: any CacheManaging = CacheManager.shared,
        api: APIService = .shared,
        audioPlayer: AudioPlayerService = .shared,
        settings: AppSettings = .shared
    ) {
        self.surahNumber = surahNumber
        self.scrollToAyah = scrollToAyah
        self.cache = cache
        self.api = api
        self.audioPlayer = audioPlayer
        self.settings = settings
    }

    func onAppear() {
        Task {
            if let cached = await cache.loadCachedSurah(surahNumber) {
                buildDisplay(arabic: cached.arabicAyahs, translation: cached.translationAyahs, transliteration: cached.transliterationAyahs)
            }
            await loadBookmarkStates()
            await fetchSurah()
        }
    }

    private func fetchSurah() async {
        isLoading = displayAyahs.isEmpty
        errorMessage = nil
        do {        
            let edition = settings.translationLanguage.rawValue
            async let arabicTask = api.fetchSurah(number: surahNumber, edition: "quran-uthmani")
            async let translationTask = api.fetchSurahTranslation(number: surahNumber, edition: edition)

            let arabic = try await arabicTask
            let translation = try await translationTask

            surahName = arabic.name
            surahEnglishName = arabic.englishName

            var transliteration: [Ayah]? = nil
            if settings.showTransliteration {
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
            await cache.cacheSurah(cached)

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
                    let q = Qari.resolve(settings.selectedQari)
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
            settings.lastReadSurah = surahNumber
            settings.lastReadAyah = ayah
        }
    }

    @Published var bookmarkedAyahs: Set<Int> = []

    func loadBookmarkStates() async {
        let bookmarks = await cache.loadAyahBookmarks()
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
            bookmarkedAyahs.remove(ayah.numberInSurah)
            Task { await cache.removeAyahBookmark(surah: surahNumber, ayah: ayah.numberInSurah) }
        } else {
            bookmarkedAyahs.insert(ayah.numberInSurah)
            let bookmark = BookmarkedAyah(
                surahNumber: surahNumber,
                surahName: surahEnglishName,
                ayahNumber: ayah.numberInSurah,
                arabicText: ayah.arabicText,
                translationText: ayah.translationText
            )
            Task { await cache.saveAyahBookmark(bookmark) }
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
