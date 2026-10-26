import Foundation
import SwiftUI

@Observable
@MainActor
final class JournalViewModel {
    var entries: [JournalEntry] = []
    var ayahBookmarks: [BookmarkedAyah] = []
    var hadithBookmarks: [BookmarkedHadith] = []

    private static let dateGroupFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private let cache: any CacheManaging

    init(cacheManager: any CacheManaging = CacheManager.shared) {
        self.cache = cacheManager
    }

    func onAppear() {
        Task { await refresh() }
    }

    func refresh() async {
        entries = await cache.loadJournalEntries().sorted { $0.date > $1.date }
        ayahBookmarks = await cache.loadAyahBookmarks()
        hadithBookmarks = await cache.loadHadithBookmarks()
    }

    func addEntry(_ entry: JournalEntry) {
        entries.insert(entry, at: 0)
        Task {
            await cache.saveJournalEntry(entry)
            CloudBackupService.shared.scheduleUpload()
        }
    }

    func updateEntry(_ entry: JournalEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        }
        Task {
            await cache.updateJournalEntry(entry)
            CloudBackupService.shared.scheduleUpload()
        }
    }

    func deleteEntry(at offsets: IndexSet) {
        let idsToRemove = offsets.map { entries[$0].id }
        entries.remove(atOffsets: offsets)
        Task {
            for id in idsToRemove {
                await cache.removeJournalEntry(id: id)
                CloudBackupService.shared.noteJournalDeleted(id)
            }
        }
    }

    func deleteEntry(_ entry: JournalEntry) {
        entries.removeAll { $0.id == entry.id }
        Task {
            await cache.removeJournalEntry(id: entry.id)
            CloudBackupService.shared.noteJournalDeleted(entry.id)
        }
    }

    var entriesByDate: [(String, [JournalEntry])] {
        let grouped = Dictionary(grouping: entries) { entry in
            Self.dateGroupFormatter.string(from: entry.date)
        }

        return grouped
            .sorted { lhs, rhs in
                guard let lDate = lhs.value.first?.date, let rDate = rhs.value.first?.date else { return false }
                return lDate > rDate
            }
    }
}
