import Foundation

// MARK: - CacheManager
//
// Design decisions:
//   - CacheManager is a Swift actor. All mutable state is protected by the actor's
//     implicit serial executor, which guarantees that read-modify-write cycles
//     (e.g. load bookmarks → insert → save) are atomic without manual locking.
//   - NSCache is used as an in-memory layer. It is thread-safe for concurrent
//     get/set calls, so no extra synchronisation is required on the memory layer.
//   - Disk I/O runs inline within the actor's executor. Because actors use a
//     cooperative thread pool, this never blocks the main thread.
//   - All public methods are async. Callers (ViewModels on @MainActor) use `await`.

actor CacheManager {

    // MARK: - Shared Instance

    /// The singleton used by production code.
    static let shared = CacheManager()

    // MARK: - App Group

    /// The App Group identifier shared between the Kheir app target and the KheirWidget extension.
    /// Both targets must declare this group under Signing & Capabilities → App Groups.
    static let appGroupIdentifier = "group.com.kheir.shared"

    // MARK: - Cached Coders

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    // MARK: - Private State

    private let fileManager = FileManager.default

    /// Root cache directory — either inside the shared App Group container or the Documents
    /// directory fallback when the capability has not yet been configured.
    private let cacheDirectory: URL

    /// In-memory store keyed by filename. NSCache evicts automatically under memory pressure and
    /// is thread-safe for concurrent get/set calls, so no extra synchronisation is required on
    /// the memory layer itself.
    private let memoryCache = NSCache<NSString, CacheBox>()

    // MARK: - Filename Constants

    private let ayahBookmarksFile  = "bookmarked_ayahs.json"
    private let hadithBookmarksFile = "bookmarked_hadiths.json"
    private let journalFile         = "journal_entries.json"

    // MARK: - Initialisation

    private init() {
        let containerURL: URL
        if let groupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: CacheManager.appGroupIdentifier
        ) {
            containerURL = groupURL
        } else {
            // Fallback: App Group capability not yet configured in Xcode.
            // The app continues to work using the Documents directory until the
            // capability is added and the migration runs on next launch.
            let paths = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
            containerURL = paths[0]
        }
        cacheDirectory = containerURL.appendingPathComponent("NurAppCache", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)

        // Warm the two most-read collections so the first bookmark / journal call is instant.
        warmMemoryCache(filename: ayahBookmarksFile,  type: [BookmarkedAyah].self)
        warmMemoryCache(filename: hadithBookmarksFile, type: [BookmarkedHadith].self)
        warmMemoryCache(filename: journalFile,          type: [JournalEntry].self)

        migrateToAppGroupIfNeeded()
    }

    // MARK: - Memory Cache Helpers

    /// A type-erased box stored inside NSCache. NSCache requires reference-type values.
    private final class CacheBox {
        let data: Data
        init(_ data: Data) { self.data = data }
    }

    /// Reads `filename` from disk synchronously on the calling thread (init only) and inserts
    /// the raw bytes into the memory cache so the first real read is instant.
    private func warmMemoryCache<T: Decodable>(filename: String, type: T.Type) {
        let url = cacheDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return }
        memoryCache.setObject(CacheBox(data), forKey: filename as NSString)
    }

    // MARK: - App Group Migration

    /// Copies pre-existing cache files from the legacy Documents/NurAppCache directory into the
    /// App Group shared container exactly once. The migration only runs when:
    ///   1. The App Group container is accessible (capability is configured), AND
    ///   2. The legacy Documents cache directory contains files to migrate.
    /// A marker file `migrated_to_app_group_v1` inside the container prevents repeat runs.
    func migrateToAppGroupIfNeeded() {
        guard let groupURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: CacheManager.appGroupIdentifier
        ) else { return }

        let containerCache = groupURL.appendingPathComponent("NurAppCache", isDirectory: true)
        let markerURL = containerCache.appendingPathComponent("migrated_to_app_group_v1")

        guard !fileManager.fileExists(atPath: markerURL.path) else { return }

        let legacyCache = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NurAppCache", isDirectory: true)

        guard
            fileManager.fileExists(atPath: legacyCache.path),
            let legacyFiles = try? fileManager.contentsOfDirectory(
                at: legacyCache,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            ),
            !legacyFiles.isEmpty
        else {
            try? fileManager.createDirectory(at: containerCache, withIntermediateDirectories: true)
            fileManager.createFile(atPath: markerURL.path, contents: nil)
            return
        }

        try? fileManager.createDirectory(at: containerCache, withIntermediateDirectories: true)

        for sourceURL in legacyFiles {
            let destinationURL = containerCache.appendingPathComponent(sourceURL.lastPathComponent)
            if !fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
        }

        fileManager.createFile(atPath: markerURL.path, contents: nil)
    }

    // MARK: - Generic Save / Load

    /// Encodes `object` and persists it to both the in-memory cache and disk.
    /// The actor's serial executor ensures this entire operation is atomic.
    func save<T: Encodable>(_ object: T, filename: String) {
        guard let data = try? Self.encoder.encode(object) else {
            print("CacheManager: failed to encode \(T.self) for '\(filename)'")
            return
        }
        memoryCache.setObject(CacheBox(data), forKey: filename as NSString)

        let url = cacheDirectory.appendingPathComponent(filename)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            print("CacheManager: disk write error for '\(filename)': \(error)")
        }
    }

    /// Decodes and returns a value of `type` from cache.
    /// Checks the memory layer first; falls back to disk when NSCache has evicted the entry.
    /// The actor guarantees no concurrent access, so no queue synchronisation is needed.
    func load<T: Decodable>(_ type: T.Type, filename: String) -> T? {
        // Fast path: memory hit.
        if let box = memoryCache.object(forKey: filename as NSString) {
            return try? Self.decoder.decode(type, from: box.data)
        }

        // Slow path: evicted from memory, read from disk.
        let url = cacheDirectory.appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }

        // Re-insert into memory cache so the next call is fast.
        memoryCache.setObject(CacheBox(data), forKey: filename as NSString)
        return try? Self.decoder.decode(type, from: data)
    }

    /// Returns `true` when a file with `filename` exists in the cache directory.
    /// Does NOT check the memory cache — this reflects the persisted state on disk.
    func exists(filename: String) -> Bool {
        let url = cacheDirectory.appendingPathComponent(filename)
        return fileManager.fileExists(atPath: url.path)
    }

    /// Removes the file with `filename` from both the memory cache and disk.
    func delete(filename: String) {
        memoryCache.removeObject(forKey: filename as NSString)
        let url = cacheDirectory.appendingPathComponent(filename)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Surah Cache

    /// Caches a fully-fetched surah (Arabic + translation + transliteration).
    func cacheSurah(_ surah: CachedSurah) {
        save(surah, filename: "surah_\(surah.surahNumber).json")
    }

    /// Returns a previously cached surah, or `nil` if not yet downloaded.
    func loadCachedSurah(_ number: Int) -> CachedSurah? {
        load(CachedSurah.self, filename: "surah_\(number).json")
    }

    // MARK: - Surah List Cache

    /// Persists the full list of surah metadata for offline use.
    func cacheSurahList(_ list: [SurahInfo]) {
        save(list, filename: "surah_list.json")
    }

    /// Returns the cached surah list, or `nil` if not yet downloaded.
    func loadSurahList() -> [SurahInfo]? {
        load([SurahInfo].self, filename: "surah_list.json")
    }

    // MARK: - Daily Content Cache

    /// Persists today's randomly-selected Ayah for the Home screen widget.
    func cacheDailyAyah(_ ayah: DailyAyah) {
        save(ayah, filename: "daily_ayah_\(ayah.dateString).json")
    }

    /// Returns the cached `DailyAyah` for `date`, or `nil` if not yet fetched today.
    func loadDailyAyah(for date: String) -> DailyAyah? {
        load(DailyAyah.self, filename: "daily_ayah_\(date).json")
    }

    /// Persists today's randomly-selected Hadith for the Home screen widget.
    func cacheDailyHadith(_ hadith: DailyHadith) {
        save(hadith, filename: "daily_hadith_\(hadith.dateString).json")
    }

    /// Returns the cached `DailyHadith` for `date`, or `nil` if not yet fetched today.
    func loadDailyHadith(for date: String) -> DailyHadith? {
        load(DailyHadith.self, filename: "daily_hadith_\(date).json")
    }

    // MARK: - Streak Cache

    /// Persists the user's streak data. The memory cache is updated immediately;
    /// disk I/O is dispatched asynchronously on `ioQueue`.
    func saveStreak(_ data: StreakData) {
        save(data, filename: "streak_data.json")
    }

    /// Returns the persisted `StreakData`, or `nil` if the user has never opened the app
    /// on a day that called `saveStreak`.
    func loadStreak() -> StreakData? {
        load(StreakData.self, filename: "streak_data.json")
    }

    // MARK: - Routine Cache

    /// Persists a `DailyRoutine` including its current `completedSteps` progress.
    /// The filename encodes both the routine type and the calendar date so morning
    /// and evening routines are stored independently.
    func saveRoutine(_ routine: DailyRoutine) {
        save(routine, filename: "routine_\(routine.type.rawValue)_\(routine.dateString).json")
    }

    /// Returns the cached `DailyRoutine` for the given type and date, or `nil` if
    /// no routine has been generated or saved yet.
    func loadRoutine(type: RoutineType, for date: String) -> DailyRoutine? {
        load(DailyRoutine.self, filename: "routine_\(type.rawValue)_\(date).json")
    }
}

// MARK: - Ayah Bookmarks

extension CacheManager {

    /// Returns all saved Ayah bookmarks, newest first.
    /// Reads from the memory cache; hits disk only when NSCache has evicted the entry.
    func loadAyahBookmarks() -> [BookmarkedAyah] {
        load([BookmarkedAyah].self, filename: ayahBookmarksFile) ?? []
    }

    /// Inserts `bookmark` at the front of the list and persists asynchronously.
    func saveAyahBookmark(_ bookmark: BookmarkedAyah) {
        // Mutate the current list, update memory, queue disk write — all without locking.
        var bookmarks = loadAyahBookmarks()
        bookmarks.insert(bookmark, at: 0)
        save(bookmarks, filename: ayahBookmarksFile)
    }

    /// Removes the bookmark matching the given surah / ayah coordinate.
    func removeAyahBookmark(surah: Int, ayah: Int) {
        var bookmarks = loadAyahBookmarks()
        bookmarks.removeAll { $0.surahNumber == surah && $0.ayahNumber == ayah }
        save(bookmarks, filename: ayahBookmarksFile)
    }

    /// Removes the bookmark with the given stable `id`.
    func removeAyahBookmark(id: UUID) {
        var bookmarks = loadAyahBookmarks()
        bookmarks.removeAll { $0.id == id }
        save(bookmarks, filename: ayahBookmarksFile)
    }

    /// Returns `true` when an Ayah at the given position is in the bookmark list.
    func isAyahBookmarked(surah: Int, ayah: Int) -> Bool {
        loadAyahBookmarks().contains { $0.surahNumber == surah && $0.ayahNumber == ayah }
    }
}

// MARK: - Hadith Bookmarks

extension CacheManager {

    /// Returns all saved Hadith bookmarks, newest first.
    func loadHadithBookmarks() -> [BookmarkedHadith] {
        load([BookmarkedHadith].self, filename: hadithBookmarksFile) ?? []
    }

    /// Inserts `bookmark` at the front of the list and persists asynchronously.
    func saveHadithBookmark(_ bookmark: BookmarkedHadith) {
        var bookmarks = loadHadithBookmarks()
        bookmarks.insert(bookmark, at: 0)
        save(bookmarks, filename: hadithBookmarksFile)
    }

    /// Removes the bookmark matching the given text and source combination.
    func removeHadithBookmark(text: String, source: String) {
        var bookmarks = loadHadithBookmarks()
        bookmarks.removeAll { $0.text == text && $0.source == source }
        save(bookmarks, filename: hadithBookmarksFile)
    }

    /// Removes the bookmark with the given stable `id`.
    func removeHadithBookmark(id: UUID) {
        var bookmarks = loadHadithBookmarks()
        bookmarks.removeAll { $0.id == id }
        save(bookmarks, filename: hadithBookmarksFile)
    }

    /// Returns `true` when a Hadith with the given text and source is in the bookmark list.
    func isHadithBookmarked(text: String, source: String) -> Bool {
        loadHadithBookmarks().contains { $0.text == text && $0.source == source }
    }
}

// MARK: - Journal

extension CacheManager {

    /// Returns all journal entries, newest first.
    func loadJournalEntries() -> [JournalEntry] {
        load([JournalEntry].self, filename: journalFile) ?? []
    }

    /// Inserts `entry` at the front of the list and persists asynchronously.
    func saveJournalEntry(_ entry: JournalEntry) {
        var entries = loadJournalEntries()
        entries.insert(entry, at: 0)
        save(entries, filename: journalFile)
    }

    /// Replaces the existing entry with the same `id` in-place and persists asynchronously.
    func updateJournalEntry(_ entry: JournalEntry) {
        var entries = loadJournalEntries()
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        }
        save(entries, filename: journalFile)
    }

    /// Removes the entry with the given `id` and persists asynchronously.
    func removeJournalEntry(id: UUID) {
        var entries = loadJournalEntries()
        entries.removeAll { $0.id == id }
        save(entries, filename: journalFile)
    }
}
