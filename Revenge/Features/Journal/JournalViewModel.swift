import Foundation
import Combine
import SwiftUI

@MainActor
final class JournalViewModel: ObservableObject {
    @Published var entries: [JournalEntry] = []
    @Published var ayahBookmarks: [BookmarkedAyah] = []
    @Published var hadithBookmarks: [BookmarkedHadith] = []

    private let cache = CacheManager.shared

    func onAppear() {
        refresh()
    }

    func refresh() {
        entries = cache.loadJournalEntries()
        ayahBookmarks = cache.loadAyahBookmarks()
        hadithBookmarks = cache.loadHadithBookmarks()
    }

    func addEntry(_ entry: JournalEntry) {
        cache.saveJournalEntry(entry)
        entries.insert(entry, at: 0)
    }

    func updateEntry(_ entry: JournalEntry) {
        cache.updateJournalEntry(entry)
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        }
    }

    func deleteEntry(at offsets: IndexSet) {
        for index in offsets {
            cache.removeJournalEntry(id: entries[index].id)
        }
        entries.remove(atOffsets: offsets)
    }

    func deleteEntry(_ entry: JournalEntry) {
        cache.removeJournalEntry(id: entry.id)
        entries.removeAll { $0.id == entry.id }
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
