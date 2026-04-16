import Foundation
import Combine

@MainActor
final class SurahListViewModel: ObservableObject {
    @Published var surahs: [SurahInfo] = []
    @Published var filteredSurahs: [SurahInfo] = []
    @Published var searchText: String = ""
    @Published var isLoading = false

    private let cache = CacheManager.shared
    private var searchCancellable: AnyCancellable?

    var lastReadSurah: Int { AppSettings.shared.lastReadSurah }
    var lastReadAyah: Int { AppSettings.shared.lastReadAyah }

    init() {
        searchCancellable = $searchText
            .debounce(for: .milliseconds(200), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.filterSurahs()
            }
    }

    func onAppear() {
        if let cached = cache.loadSurahList() {
            surahs = cached
            filteredSurahs = cached
        }
        Task { await fetchSurahs() }
    }

    private func fetchSurahs() async {
        guard surahs.isEmpty else { return }
        isLoading = true
        do {
            let list = try await APIService.shared.fetchSurahList()
            surahs = list
            filteredSurahs = list
            cache.cacheSurahList(list)
        } catch {
            print("Surah list error: \(error)")
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
