import Foundation
import Combine
import SwiftUI

@MainActor
final class JournalViewModel: ObservableObject {
    @Published var entries: [JournalEntry] = []
    @Published var ayahBookmarks: [BookmarkedAyah] = []
    @Published var hadithBookmarks: [BookmarkedHadith] = []

    private let cache: any CacheManaging

    init(cacheManager: any CacheManaging = CacheManager.shared) {
        self.cache = cacheManager
    }

    func onAppear() {
        Task { await refresh() }
    }

    func refresh() async {
        entries = await cache.loadJournalEntries()
        ayahBookmarks = await cache.loadAyahBookmarks()
        hadithBookmarks = await cache.loadHadithBookmarks()
    }

    func addEntry(_ entry: JournalEntry) {
        entries.insert(entry, at: 0)
        Task { await cache.saveJournalEntry(entry) }
    }

    func updateEntry(_ entry: JournalEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        }
        Task { await cache.updateJournalEntry(entry) }
    }

    func deleteEntry(at offsets: IndexSet) {
        let idsToRemove = offsets.map { entries[$0].id }
        entries.remove(atOffsets: offsets)
        Task {
            for id in idsToRemove {
                await cache.removeJournalEntry(id: id)
            }
        }
    }

    func deleteEntry(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        Task { await cache.removeJournalEntry(id: entry.id) }
    }

    var entriesByDate: [(String, [JournalEntry])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let grouped = Dictionary(grouping: entries) { entry in
            formatter.string(from: entry.date)
        }

        return grouped
            .sorted { lhs, rhs in
                guard let lDate = lhs.value.first?.date, let rDate = rhs.value.first?.date else { return false }
                return lDate > rDate
            }
    }
}
