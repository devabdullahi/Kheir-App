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

    private let cache = CacheManager.shared

    func onAppear() {
        refresh()
    }

    func refresh() {
        ayahBookmarks = cache.loadAyahBookmarks()
        hadithBookmarks = cache.loadHadithBookmarks()
    }

    func deleteAyahBookmark(at offsets: IndexSet) {
        for index in offsets {
            cache.removeAyahBookmark(id: ayahBookmarks[index].id)
        }
        ayahBookmarks.remove(atOffsets: offsets)
    }

    func deleteHadithBookmark(at offsets: IndexSet) {
        for index in offsets {
            cache.removeHadithBookmark(id: hadithBookmarks[index].id)
        }
        hadithBookmarks.remove(atOffsets: offsets)
    }

    func removeAyahBookmark(_ bookmark: BookmarkedAyah) {
        cache.removeAyahBookmark(id: bookmark.id)
        ayahBookmarks.removeAll { $0.id == bookmark.id }
    }

    func removeHadithBookmark(_ bookmark: BookmarkedHadith) {
        cache.removeHadithBookmark(id: bookmark.id)
        hadithBookmarks.removeAll { $0.id == bookmark.id }
    }

    var totalBookmarkCount: Int {
        ayahBookmarks.count + hadithBookmarks.count
    }
}
