import Foundation
import Observation
import os

// MARK: - CloudBackupService
//
// Backs up the user's progress to iCloud so it comes back on a new iPhone signed
// into the same Apple ID: the streak, today's and yesterday's routine progress,
// the journal and the personalisation settings.
//
// Design decisions:
//   - Storage is `NSUbiquitousKeyValueStore`: no CloudKit schema, no account UI,
//     and it syncs automatically. Its limits are 1 MB total and 1 MB per key, so
//     everything here is small JSON. The journal is the only thing that can grow;
//     it is trimmed newest-first to `journalBudget` bytes (thousands of typical
//     entries). Entries beyond the budget stay on the device only.
//   - Nothing happens unless `AppSettings.iCloudBackup` is on.
//   - Merge rules (never lose progress):
//       • Streak: the newer `lastOpenedDate` wins; if the older side's streak was
//         still alive (0–1 day gap) and larger, it carries on; `longestStreak` is
//         the max of both.
//       • Routines: per (type, day), completed steps are unioned; a routine that
//         only exists remotely is restored as is.
//       • Journal: union by entry id, minus ids deleted on either device
//         (tombstones). An entry present on both keeps the local copy.
//       • Settings: last writer wins, by the time the settings last changed.
//   - All work runs on the main actor; disk I/O goes through the `CacheManager`
//     actor, so nothing blocks the UI.
@MainActor
@Observable
final class CloudBackupService {

    static let shared = CloudBackupService()

    // MARK: Public state

    /// When this device last wrote a backup (or restored one), for the Settings row.
    private(set) var lastSynced: Date?
    /// `false` when no iCloud account is signed in on this device.
    private(set) var isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil
    private(set) var isSyncing = false

    // MARK: Private

    @ObservationIgnored private let store = NSUbiquitousKeyValueStore.default
    @ObservationIgnored private let cache = CacheManager.shared
    @ObservationIgnored private let settings = AppSettings.shared
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "CloudBackup")

    @ObservationIgnored private var started = false
    @ObservationIgnored private var externalChangeTask: Task<Void, Never>?
    @ObservationIgnored private var settingsTask: Task<Void, Never>?
    @ObservationIgnored private var uploadTask: Task<Void, Never>?
    /// The settings as last written to or read from iCloud; changes from it are local edits.
    @ObservationIgnored private var syncedSettings: BackupSettings?

    /// Bytes the journal may use in the key-value store (1 MB total for everything).
    static let journalBudget = 700_000

    enum Key {
        static let prefix = "kheir.backup.v1."
        static let streak = prefix + "streak"
        static let routines = prefix + "routines"
        static let journal = prefix + "journal"
        static let tombstones = prefix + "journalDeleted"
        static let settings = prefix + "settings"
        static let settingsChangedAt = prefix + "settingsChangedAt"
        static let updatedAt = prefix + "updatedAt"
        static let all = [streak, routines, journal, tombstones, settings, settingsChangedAt, updatedAt]

        // Local bookkeeping (UserDefaults)
        static let localSettingsChangedAt = "cloudBackup.settingsChangedAt"
        static let localTombstones = "cloudBackup.journalDeleted"
        static let localLastSynced = "cloudBackup.lastSynced"
    }

    private init() {
        let t = defaults.double(forKey: Key.localLastSynced)
        lastSynced = t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    // MARK: - Lifecycle

    /// Call once at launch (idempotent). Starts listening for changes from other
    /// devices and, when backup is on, restores then uploads.
    func start() {
        guard !started else { return }
        started = true

        externalChangeTask = Task { [weak self] in
            let changes = NotificationCenter.default.notifications(
                named: NSUbiquitousKeyValueStore.didChangeExternallyNotification
            )
            for await _ in changes {
                guard let self else { return }
                guard self.settings.iCloudBackup else { continue }
                await self.restore()
            }
        }

        settingsTask = Task { [weak self] in
            for await snapshot in Observations({ BackupSettings(AppSettings.shared) }) {
                guard let self else { return }
                self.settingsDidChange(snapshot)
            }
        }

        if settings.iCloudBackup {
            Task { await syncNow() }
        }
    }

    /// Turn backup on or off (the Settings toggle). Turning it on restores
    /// whatever is in iCloud, merges it with this device and uploads the result.
    func setEnabled(_ enabled: Bool) {
        start()
        settings.iCloudBackup = enabled
        if enabled {
            Task { await syncNow() }
        } else {
            uploadTask?.cancel()
        }
    }

    /// Restore + merge, then upload. Safe to call any time.
    func syncNow() async {
        guard settings.iCloudBackup else { return }
        isICloudAvailable = FileManager.default.ubiquityIdentityToken != nil
        isSyncing = true
        defer { isSyncing = false }
        store.synchronize()
        await restore()
        await upload()
    }

    /// Debounced upload after a local change (journal entry, routine tick, …).
    /// A no-op while backup is off.
    func scheduleUpload() {
        guard settings.iCloudBackup else { return }
        start()
        uploadTask?.cancel()
        uploadTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled, let self else { return }
            await self.upload()
        }
    }

    /// Remember a deleted journal entry so a merge never brings it back.
    func noteJournalDeleted(_ id: UUID) {
        var ids = defaults.stringArray(forKey: Key.localTombstones) ?? []
        ids.append(id.uuidString)
        defaults.set(Array(ids.suffix(500)), forKey: Key.localTombstones)
        scheduleUpload()
    }

    /// Removes everything Kheir stored in iCloud. Data on this device is kept.
    func deleteBackup() {
        uploadTask?.cancel()
        for key in Key.all { store.removeObject(forKey: key) }
        store.synchronize()
        lastSynced = nil
        defaults.removeObject(forKey: Key.localLastSynced)
    }

    // MARK: - Upload

    func upload() async {
        guard settings.iCloudBackup else { return }

        if let streak = await cache.loadStreak(), let data = try? JSONEncoder().encode(streak) {
            store.set(data, forKey: Key.streak)
        }

        let routines = await recentRoutines()
        if let data = try? JSONEncoder().encode(routines) {
            store.set(data, forKey: Key.routines)
        }

        let journal = await cache.loadJournalEntries().sorted { $0.date > $1.date }
        store.set(Self.trimmedJournal(journal), forKey: Key.journal)

        let remoteTombstones = store.array(forKey: Key.tombstones) as? [String] ?? []
        let localTombstones = defaults.stringArray(forKey: Key.localTombstones) ?? []
        store.set(Array(Set(remoteTombstones + localTombstones)).suffix(500).sorted(), forKey: Key.tombstones)

        let snapshot = BackupSettings(settings)
        if let data = try? JSONEncoder().encode(snapshot) {
            store.set(data, forKey: Key.settings)
            store.set(localSettingsChangedAt, forKey: Key.settingsChangedAt)
            syncedSettings = snapshot
        }

        let now = Date()
        store.set(now.timeIntervalSince1970, forKey: Key.updatedAt)
        store.synchronize()
        lastSynced = now
        defaults.set(now.timeIntervalSince1970, forKey: Key.localLastSynced)
        logger.debug("Uploaded backup (\(journal.count) journal entries)")
    }

    /// The journal encoded newest-first, trimmed to fit `journalBudget`.
    static func trimmedJournal(_ entries: [JournalEntry]) -> Data {
        let encoder = JSONEncoder()
        var kept = entries
        guard var data = try? encoder.encode(kept) else { return Data("[]".utf8) }
        while data.count > journalBudget, !kept.isEmpty {
            // Drop roughly the overflow share of the oldest entries at once.
            let overflow = Double(data.count - journalBudget) / Double(data.count)
            let drop = max(1, Int(Double(kept.count) * overflow))
            kept.removeLast(min(drop, kept.count))
            data = (try? encoder.encode(kept)) ?? Data("[]".utf8)
        }
        return data
    }

    // MARK: - Restore

    func restore() async {
        guard settings.iCloudBackup else { return }
        let decoder = JSONDecoder()

        // Streak
        if let data = store.data(forKey: Key.streak),
           let remote = try? decoder.decode(StreakData.self, from: data) {
            let local = await cache.loadStreak()
            let merged = Self.mergeStreak(local: local, remote: remote)
            if merged != local { await cache.saveStreak(merged) }
        }

        // Routines
        if let data = store.data(forKey: Key.routines),
           let remote = try? decoder.decode([DailyRoutine].self, from: data) {
            for routine in remote {
                let local = await cache.loadRoutine(type: routine.type, for: routine.dateString)
                if let merged = Self.mergeRoutine(local: local, remote: routine) {
                    await cache.saveRoutine(merged)
                }
            }
        }

        // Journal
        let remoteTombstones = Set(store.array(forKey: Key.tombstones) as? [String] ?? [])
        let localTombstones = Set(defaults.stringArray(forKey: Key.localTombstones) ?? [])
        let deleted = remoteTombstones.union(localTombstones)
        if let data = store.data(forKey: Key.journal),
           let remote = try? decoder.decode([JournalEntry].self, from: data) {
            let local = await cache.loadJournalEntries()
            let localIDs = Set(local.map(\.id))
            for entry in local where deleted.contains(entry.id.uuidString) {
                await cache.removeJournalEntry(id: entry.id)
            }
            // Oldest first, so the newest ends up at the front of the list.
            let missing = remote
                .filter { !localIDs.contains($0.id) && !deleted.contains($0.id.uuidString) }
                .sorted { $0.date < $1.date }
            for entry in missing { await cache.saveJournalEntry(entry) }
        }
        defaults.set(Array(deleted).suffix(500).sorted(), forKey: Key.localTombstones)

        // Settings: last writer wins.
        if let data = store.data(forKey: Key.settings),
           let remote = try? decoder.decode(BackupSettings.self, from: data) {
            let remoteChangedAt = store.double(forKey: Key.settingsChangedAt)
            if remoteChangedAt > localSettingsChangedAt {
                syncedSettings = remote
                remote.apply(to: settings)
                defaults.set(remoteChangedAt, forKey: Key.localSettingsChangedAt)
            }
        }

        NotificationCenter.default.post(name: .cloudBackupDidRestore, object: nil)
    }

    // MARK: - Merge rules

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        return f
    }()

    /// Keeps the newer day; carries a larger streak over if it was still alive.
    static func mergeStreak(local: StreakData?, remote: StreakData) -> StreakData {
        guard let local, !local.lastOpenedDate.isEmpty else { return remote }
        guard !remote.lastOpenedDate.isEmpty else { return local }

        let (newer, older) = local.lastOpenedDate >= remote.lastOpenedDate ? (local, remote) : (remote, local)
        var merged = newer
        merged.longestStreak = max(local.longestStreak, remote.longestStreak)

        if let a = dayFormatter.date(from: older.lastOpenedDate),
           let b = dayFormatter.date(from: newer.lastOpenedDate),
           let gap = Calendar.current.dateComponents([.day], from: a, to: b).day,
           gap <= 1 {
            merged.currentStreak = max(newer.currentStreak, older.currentStreak + gap)
        }
        merged.longestStreak = max(merged.longestStreak, merged.currentStreak)
        return merged
    }

    /// Union of completed steps; `nil` when the local copy already has everything.
    static func mergeRoutine(local: DailyRoutine?, remote: DailyRoutine) -> DailyRoutine? {
        guard var local else { return remote }
        let localIDs = Set(local.steps.map(\.id))
        let remoteIDs = Set(remote.steps.map(\.id))
        if localIDs == remoteIDs {
            let union = local.completedSteps.union(remote.completedSteps)
            guard union != local.completedSteps else { return nil }
            local.completedSteps = union
            return local
        }
        // Generated separately on each device (new step ids): match steps by position and title.
        var changed = false
        for (i, step) in remote.steps.enumerated()
        where remote.completedSteps.contains(step.id) && i < local.steps.count && local.steps[i].title == step.title {
            if local.completedSteps.insert(local.steps[i].id).inserted { changed = true }
        }
        return changed ? local : nil
    }

    // MARK: - Helpers

    private var localSettingsChangedAt: Double {
        defaults.double(forKey: Key.localSettingsChangedAt)
    }

    private func settingsDidChange(_ snapshot: BackupSettings) {
        if syncedSettings == nil {
            // First emission: the current state, not an edit.
            syncedSettings = snapshot
            if localSettingsChangedAt == 0 {
                defaults.set(Date().timeIntervalSince1970, forKey: Key.localSettingsChangedAt)
            }
            return
        }
        guard snapshot != syncedSettings else { return }
        defaults.set(Date().timeIntervalSince1970, forKey: Key.localSettingsChangedAt)
        scheduleUpload()
    }

    /// Today's and yesterday's routines (both kinds) that exist on this device.
    private func recentRoutines() async -> [DailyRoutine] {
        let today = Date()
        let days = [today, Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today]
        var out: [DailyRoutine] = []
        for day in days {
            let key = Self.dayFormatter.string(from: day)
            for type in RoutineType.allCases {
                if let routine = await cache.loadRoutine(type: type, for: key) { out.append(routine) }
            }
        }
        return out
    }
}

extension Notification.Name {
    /// Posted after a backup from iCloud was merged into this device's data.
    static let cloudBackupDidRestore = Notification.Name("cloudBackupDidRestore")
}

// MARK: - Settings snapshot

/// The personalisation and preference settings that travel with the backup.
struct BackupSettings: Codable, Equatable, Sendable {
    var userName: String
    var journey: String
    var intentions: [String]
    var arabicLevel: String
    var quranGoal: String
    var fajrWakeOffset: Int?
    var morningAdhkarMinutes: Int
    var eveningAdhkarBeforeMaghrib: Int
    var adhkarRemindersOn: Bool
    var weeklyReminders: [String]
    var duaNames: [DuaName]
    var appTheme: String
    var arabicFontSize: Double
    var showTransliteration: Bool
    var translationLanguage: String
    var selectedQari: String
    var calculationMethod: String
    var madhab: String
    var lastReadSurah: Int
    var lastReadAyah: Int

    @MainActor
    init(_ s: AppSettings) {
        userName = s.userName
        journey = s.journey.rawValue
        intentions = s.intentions.map(\.rawValue).sorted()
        arabicLevel = s.arabicLevel.rawValue
        quranGoal = s.quranGoal.rawValue
        fajrWakeOffset = s.fajrWakeOffset
        morningAdhkarMinutes = s.morningAdhkarMinutes
        eveningAdhkarBeforeMaghrib = s.eveningAdhkarBeforeMaghrib
        adhkarRemindersOn = s.adhkarRemindersOn
        weeklyReminders = s.weeklyReminders.map(\.rawValue).sorted()
        duaNames = s.duaNames
        appTheme = s.appTheme.rawValue
        arabicFontSize = s.arabicFontSize
        showTransliteration = s.showTransliteration
        translationLanguage = s.translationLanguage.rawValue
        selectedQari = s.selectedQari
        calculationMethod = s.calculationMethod.rawValue
        madhab = s.madhab.rawValue
        lastReadSurah = s.lastReadSurah
        lastReadAyah = s.lastReadAyah
    }

    @MainActor
    func apply(to s: AppSettings) {
        if s.userName != userName { s.userName = userName }
        if let v = Journey(rawValue: journey), v != s.journey { s.journey = v }
        let i = Set(intentions.compactMap(Intention.init(rawValue:)))
        if i != s.intentions { s.intentions = i }
        // Arabic level resets transliteration in its didSet, so it goes first.
        if let v = ArabicLevel(rawValue: arabicLevel), v != s.arabicLevel { s.arabicLevel = v }
        if s.showTransliteration != showTransliteration { s.showTransliteration = showTransliteration }
        if let v = QuranGoal(rawValue: quranGoal), v != s.quranGoal { s.quranGoal = v }
        if s.fajrWakeOffset != fajrWakeOffset { s.fajrWakeOffset = fajrWakeOffset }
        if s.morningAdhkarMinutes != morningAdhkarMinutes { s.morningAdhkarMinutes = morningAdhkarMinutes }
        if s.eveningAdhkarBeforeMaghrib != eveningAdhkarBeforeMaghrib { s.eveningAdhkarBeforeMaghrib = eveningAdhkarBeforeMaghrib }
        if s.adhkarRemindersOn != adhkarRemindersOn { s.adhkarRemindersOn = adhkarRemindersOn }
        let w = Set(weeklyReminders.compactMap(WeeklyReminder.init(rawValue:)))
        if w != s.weeklyReminders { s.weeklyReminders = w }
        if s.duaNames != duaNames { s.duaNames = duaNames }
        if let v = AppTheme(rawValue: appTheme), v != s.appTheme { s.appTheme = v }
        if s.arabicFontSize != arabicFontSize { s.arabicFontSize = arabicFontSize }
        if let v = TranslationLanguage(rawValue: translationLanguage), v != s.translationLanguage { s.translationLanguage = v }
        if s.selectedQari != selectedQari { s.selectedQari = selectedQari }
        if let v = CalculationMethodOption(rawValue: calculationMethod), v != s.calculationMethod { s.calculationMethod = v }
        if let v = MadhabOption(rawValue: madhab), v != s.madhab { s.madhab = v }
        if s.lastReadSurah != lastReadSurah { s.lastReadSurah = lastReadSurah }
        if s.lastReadAyah != lastReadAyah { s.lastReadAyah = lastReadAyah }
    }
}
