import Foundation
import os

@MainActor
@Observable
final class SurahListViewModel {
    var surahs: [SurahInfo] = []
    var filteredSurahs: [SurahInfo] = []

    /// Setting this property schedules a 200 ms debounced filter. Each change
    /// cancels the pending filter task; unchanged queries are skipped.
    var searchText: String = "" {
        didSet { scheduleFilter() }
    }

    var isLoading = false

    private let cache: any CacheManaging
    private let settings: AppSettings
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "SurahListViewModel")

    @ObservationIgnored private var searchTask: Task<Void, Never>?
    /// Last query actually applied by `filterSurahs()`, used to drop duplicates.
    @ObservationIgnored private var lastFilteredQuery: String = ""

    var lastReadSurah: Int { settings.lastReadSurah }
    var lastReadAyah: Int { settings.lastReadAyah }

    init(cache: any CacheManaging = CacheManager.shared, settings: AppSettings = .shared) {
        self.cache = cache
        self.settings = settings
    }

    deinit {
        searchTask?.cancel()
    }

    private func scheduleFilter() {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled, let self else { return }
            guard self.searchText != self.lastFilteredQuery else { return }
            self.lastFilteredQuery = self.searchText
            self.filterSurahs()
        }
    }

    func onAppear() {
        Task {
            if let cached = await cache.loadSurahList() {
                surahs = cached
                filteredSurahs = cached
            }
            await fetchSurahs()
        }
    }

    private func fetchSurahs() async {
        isLoading = surahs.isEmpty
        do {
            let list = try await APIService.shared.fetchSurahList()
            surahs = list
            filteredSurahs = list
            await cache.cacheSurahList(list)
        } catch {
            logger.error("Surah list error: \(error.localizedDescription)")
        }
        isLoading = false
    }

    private func filterSurahs() {
        if searchText.isEmpty {
            filteredSurahs = surahs
        } else {
            filteredSurahs = surahs.filter { surah in
                surah.englishName.localizedCaseInsensitiveContains(searchText) ||
                surah.name.contains(searchText) ||
                surah.englishNameTranslation.localizedCaseInsensitiveContains(searchText) ||
                "\(surah.number)" == searchText
            }
        }
    }
}
