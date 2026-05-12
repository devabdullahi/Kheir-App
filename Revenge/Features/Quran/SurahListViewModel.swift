import Foundation
import Combine
import os

@MainActor
final class SurahListViewModel: ObservableObject {
    @Published var surahs: [SurahInfo] = []
    @Published var filteredSurahs: [SurahInfo] = []
    @Published var searchText: String = ""
    @Published var isLoading = false

    private let cache: any CacheManaging
    private let settings: AppSettings
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "SurahListViewModel")
    private var searchCancellable: AnyCancellable?

    var lastReadSurah: Int { settings.lastReadSurah }
    var lastReadAyah: Int { settings.lastReadAyah }

    init(cache: any CacheManaging = CacheManager.shared, settings: AppSettings = .shared) {
        self.cache = cache
        self.settings = settings
        searchCancellable = $searchText
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.filterSurahs()
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
