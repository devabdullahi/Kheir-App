import Foundation
import Combine
import SwiftUI

@MainActor
final class BookmarksViewModel: ObservableObject {
    @Published var ayahBookmarks: [BookmarkedAyah] = []
    @Published var hadithBookmarks: [BookmarkedHadith] = []
    @Published var selectedTab: BookmarkTab = .ayahs

    enum BookmarkTab: String, CaseIterable {
        case ayahs = "Ayahs"
        case hadiths = "Hadiths"
    }

    private let cache: any CacheManaging

    init(cacheManager: any CacheManaging = CacheManager.shared) {
        self.cache = cacheManager
    }

    func onAppear() {
        Task { await refresh() }
    }

    func refresh() async {
        ayahBookmarks = await cache.loadAyahBookmarks()
        hadithBookmarks = await cache.loadHadithBookmarks()
    }

    func deleteAyahBookmark(at offsets: IndexSet) {
        let idsToRemove = offsets.map { ayahBookmarks[$0].id }
        ayahBookmarks.remove(atOffsets: offsets)
        Task {
            for id in idsToRemove {
                await cache.removeAyahBookmark(id: id)
            }
        }
    }

    func deleteHadithBookmark(at offsets: IndexSet) {
        let idsToRemove = offsets.map { hadithBookmarks[$0].id }
        hadithBookmarks.remove(atOffsets: offsets)
        Task {
            for id in idsToRemove {
                await cache.removeHadithBookmark(id: id)
            }
        }
    }

    func removeAyahBookmark(_ bookmark: BookmarkedAyah) {
        ayahBookmarks.removeAll { $0.id == bookmark.id }
        Task { await cache.removeAyahBookmark(id: bookmark.id) }
    }

    func removeHadithBookmark(_ bookmark: BookmarkedHadith) {
        hadithBookmarks.removeAll { $0.id == bookmark.id }
        Task { await cache.removeHadithBookmark(id: bookmark.id) }
    }

    var totalBookmarkCount: Int {
        ayahBookmarks.count + hadithBookmarks.count
    }
}
