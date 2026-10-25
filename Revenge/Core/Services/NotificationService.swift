import Foundation
import UserNotifications
import CoreLocation
import SwiftUI
import os

// MARK: - Notification names the app can observe

extension Notification.Name {
    /// Posted on the main thread when the user taps "I've prayed" on an athan.
    /// `userInfo`: `"prayer"` (String, e.g. "Maghrib"), `"time"` (Date of that prayer).
    /// The prayer is already recorded in `PrayerLog` before this is posted.
    static let kheirPrayerMarkedPrayed = Notification.Name("kheir.prayerMarkedPrayed")
    /// Posted on the main thread when a notification asks the app to open a screen.
    /// `object` is a `URL`: `kheir://qibla` or `kheir://prayer`. The same URL is
    /// kept in `NotificationService.pendingDeepLink` for a cold launch.
    static let kheirOpenDeepLink = Notification.Name("kheir.openDeepLink")
}

// MARK: - NotificationService
//
// Athan notifications ("Maghrib · 6:12 PM", the Arabic call to prayer, then a
// line in English), Fajr wake-up, weekly and Hijri reminders.
//
// Athan audio: put a ≤30 s Core Audio file in the app bundle named
//   athan_<voice>.caf        e.g. athan_makkah.caf
//   athan_<voice>_fajr.caf   (optional) Fajr version with "aṣ-ṣalātu khayrun min an-nawm"
// where <voice> is `AppSettings.azanSound` without its "azan_" prefix
// ("azan_makkah" → "makkah"). When no file is bundled the system sound plays.
// `azanSound` = "silent" schedules the athan without sound.

final class NotificationService: Sendable {
    static let shared = NotificationService()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "NotificationService")
    private let delegate = NotificationDelegate()
    private init() {}

    enum Category {
        static let prayer = "PRAYER_TIME"
        static let reminder = "KHEIR_REMINDER"
    }

    enum Action {
        static let prayed = "PRAYED"
        static let snooze = "REMIND_10"
        static let qibla = "SHOW_QIBLA"
    }

    /// Identifier prefixes this service owns; rescheduling replaces all of them.
    private static let ownedPrefixes = ["prayer_", "fajrwake_", "weekly_", "hijri_"]

    /// A deep link from a notification that the UI has not handled yet (cold launch).
    @MainActor static var pendingDeepLink: URL?

    /// Returns and clears `pendingDeepLink`.
    @MainActor func takePendingDeepLink() -> URL? {
        defer { Self.pendingDeepLink = nil }
        return Self.pendingDeepLink
    }

    @MainActor private static var scheduleTask: Task<Void, Never>?
    @MainActor private static var lastPlan: (fingerprint: String, at: Date) = ("", .distantPast)

    /// Forces the next `schedulePrayerNotifications` call to replan (e.g. after a
    /// settings change that the fingerprint below does not cover).
    @MainActor func invalidatePlan() {
        Self.lastPlan = ("", .distantPast)
    }

    @MainActor
    private func planFingerprint(settings: AppSettings, location: CLLocationCoordinate2D?) -> String {
        let loc = location.map { String(format: "%.2f,%.2f", $0.latitude, $0.longitude) } ?? "-"
        return [
            loc, Date().dayKey, settings.calculationMethod.rawValue, settings.madhab.rawValue,
            enabledPrayerNames(settings).sorted().joined(separator: "+"),
            settings.azanSound, String(settings.fajrWakeOffset ?? -1),
            settings.weeklyReminders.map(\.rawValue).sorted().joined(separator: "+")
        ].joined(separator: "|")
    }

    // MARK: Setup

    /// Sets the notification delegate and registers the athan actions. Call once,
    /// as early as possible at launch (e.g. `RevengeApp.init`), so action taps
    /// that launch the app in the background are delivered.
    @MainActor
    func configure() {
        let center = UNUserNotificationCenter.current()
        center.delegate = delegate

        let prayed = UNNotificationAction(
            identifier: Action.prayed, title: "I’ve prayed", options: [],
            icon: UNNotificationActionIcon(systemImageName: "checkmark.circle")
        )
        let snooze = UNNotificationAction(
            identifier: Action.snooze, title: "Remind me in 10 min", options: [],
            icon: UNNotificationActionIcon(systemImageName: "clock")
        )
        let qibla = UNNotificationAction(
            identifier: Action.qibla, title: "Show Qibla", options: [.foreground],
            icon: UNNotificationActionIcon(systemImageName: "location.north.circle")
        )
        let prayer = UNNotificationCategory(
            identifier: Category.prayer, actions: [prayed, snooze, qibla],
            intentIdentifiers: [], options: []
        )
        let reminder = UNNotificationCategory(identifier: Category.reminder, actions: [], intentIdentifiers: [], options: [])
        center.setNotificationCategories([prayer, reminder])
    }

    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Notification permission error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: Scheduling

    /// Schedules from today's prayer list. If a location is known the whole week
    /// (athans, Fajr wake-up, weekly and Hijri reminders) is scheduled instead.
    /// Also updates the widget schedule and the prayer Live Activity.
    @MainActor
    func schedulePrayerNotifications(prayers: [PrayerTime], settings: AppSettings) {
        SharedPrayerSchedule.write(prayers)
        let location = LocationService.shared.lastKnownLocation ?? LocationService.shared.currentLocation
        // The view model calls this on every load; replan only when something changed
        // or the last plan is older than an hour (each plan fetches a week of times).
        let fingerprint = planFingerprint(settings: settings, location: location)
        if fingerprint == Self.lastPlan.fingerprint, Date().timeIntervalSince(Self.lastPlan.at) < 3600 {
            return
        }
        Self.lastPlan = (fingerprint, Date())
        Self.scheduleTask?.cancel()
        Self.scheduleTask = Task { @MainActor in
            if let location {
                await self.scheduleWeekOfNotifications(coordinate: (location.latitude, location.longitude), settings: settings)
            } else {
                await self.schedule(days: [prayers], settings: settings)
            }
        }
    }

    @MainActor
    func scheduleWeekOfNotifications(coordinate: (Double, Double), settings: AppSettings) async {
        let loc = CLLocationCoordinate2D(latitude: coordinate.0, longitude: coordinate.1)
        let calendar = Calendar.current
        var days: [[PrayerTime]] = []
        for dayOffset in 0..<min(AppConstants.notificationDaysAhead, 7) {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: Date()),
                  let times = await PrayerTimesService.shared.fetchPrayerTimes(
                    coordinate: loc,
                    date: date,
                    method: settings.calculationMethod,
                    madhab: settings.madhab
                  ) else { continue }
            if Task.isCancelled { return }
            days.append(times.all)
        }
        guard !days.isEmpty else { return }
        await schedule(days: days, settings: settings)
    }

    /// Replaces every pending notification this service owns with a fresh plan.
    /// `days` holds one array of prayers (Fajr…Isha, may include Sunrise) per day.
    @MainActor
    private func schedule(days: [[PrayerTime]], settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests().map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: pending.filter { id in
            Self.ownedPrefixes.contains { id.hasPrefix($0) }
        })
        SharedPrayerSchedule.write(days.flatMap { $0 })

        let enabled = enabledPrayerNames(settings)
        let now = Date()
        var requests: [UNNotificationRequest] = []

        for day in days {
            for prayer in day where enabled.contains(prayer.name) && prayer.time > now {
                let content = athanContent(for: prayer, settings: settings)
                requests.append(request(id: "prayer_\(prayer.name)_\(prayer.time.dayKey)", content: content, at: prayer.time))
            }
            requests += fajrWakeRequests(day: day, settings: settings, now: now)
            requests += weeklyRequests(day: day, settings: settings, now: now)
            requests += hijriRequests(day: day, settings: settings, now: now)
        }

        // iOS keeps at most 64 pending requests per app: earliest first.
        for request in requests.sorted(by: { fireDate($0) < fireDate($1) }).prefix(60) {
            do {
                try await center.add(request)
            } catch {
                logger.error("Failed to schedule \(request.identifier): \(error.localizedDescription)")
            }
        }

        await PrayerLiveActivityManager.shared.refresh()
    }

    /// A notification "Maghrib · 6:12 PM" again in ten minutes.
    @MainActor
    func scheduleSnooze(prayer name: String, time: Date) async {
        let prayer = PrayerTime(name: name, time: time, icon: "")
        let content = athanContent(for: prayer, settings: .shared, snoozed: true)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: "snooze_\(name)_\(time.dayKey)", content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            logger.error("Failed to schedule snooze: \(error.localizedDescription)")
        }
    }

    /// Fires a sample athan (Maghrib) in five seconds, with actions and thumbnail.
    @MainActor
    func sendTestNotification() {
        let prayer = PrayerTime(name: "Maghrib", time: Date().addingTimeInterval(5), icon: "")
        let content = athanContent(for: prayer, settings: .shared)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        let request = UNNotificationRequest(identifier: "kheir_test_notification", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                self.logger.error("Test notification error: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Content

    @MainActor
    private func athanContent(for prayer: PrayerTime, settings: AppSettings, snoozed: Bool = false) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let isFriday = Calendar.current.component(.weekday, from: prayer.time) == 6
        content.title = "\(prayer.name) · \(prayer.timeString)"
        content.threadIdentifier = "prayers-\(prayer.time.dayKey)"
        content.userInfo = ["prayer": prayer.name, "time": prayer.time.timeIntervalSince1970]

        if prayer.name == "Sunrise" {
            content.body = "The sun is rising — the time for Fajr has ended."
            content.interruptionLevel = .active
            content.sound = .default
            content.categoryIdentifier = Category.reminder
        } else {
            let line: String
            if snoozed {
                line = "A gentle reminder — have you prayed \(prayer.name) yet?"
            } else {
                line = Self.callLine(for: prayer.name, friday: isFriday)
            }
            content.body = "حَيَّ عَلَى ٱلصَّلَاةِ\n\(line)"
            content.interruptionLevel = .timeSensitive
            content.relevanceScore = 1
            content.categoryIdentifier = Category.prayer
            content.sound = snoozed ? .default : athanSound(for: prayer.name, settings: settings)
        }
        if let attachment = thumbnailAttachment(for: prayer.name) {
            content.attachments = [attachment]
        }
        return content
    }

    static func callLine(for name: String, friday: Bool) -> String {
        switch name {
        case "Fajr": "Come to prayer — prayer is better than sleep."
        case "Dhuhr": friday ? "Come to prayer — it’s Jumuʿah." : "Come to prayer — the sun has passed its height."
        case "Asr": "Come to prayer — the afternoon is turning."
        case "Maghrib": "Come to prayer — the sun has set."
        case "Isha": "Come to prayer — the night has come."
        default: "Come to prayer."
        }
    }

    /// `athan_<voice>[_fajr].caf` from the bundle, else the system sound.
    @MainActor
    private func athanSound(for prayer: String, settings: AppSettings) -> UNNotificationSound? {
        do {
            let raw = settings.azanSound
            if raw == "silent" || raw == "none" { return nil }
            var voice = raw
            for prefix in ["azan_", "athan_"] where voice.hasPrefix(prefix) {
                voice.removeFirst(prefix.count)
            }
            var candidates = ["athan_\(voice)"]
            if prayer == "Fajr" { candidates.insert("athan_\(voice)_fajr", at: 0) }
            for name in candidates where Bundle.main.url(forResource: name, withExtension: "caf") != nil {
                return UNNotificationSound(named: UNNotificationSoundName("\(name).caf"))
            }
            return .default
        }
    }

    // MARK: Fajr wake-up, weekly and Hijri reminders

    @MainActor
    private func fajrWakeRequests(day: [PrayerTime], settings: AppSettings, now: Date) -> [UNNotificationRequest] {
        guard let offset = settings.fajrWakeOffset, offset > 0,
              let fajr = day.first(where: { $0.name == "Fajr" }) else { return [] }
        let fire = fajr.time.addingTimeInterval(-Double(offset) * 60)
        guard fire > now else { return [] }
        let content = reminderContent(
            title: "Fajr in \(offset) minutes",
            body: "Rise gently — wudu, a glass of water, and the day begins with prayer.",
            level: .timeSensitive
        )
        return [request(id: "fajrwake_\(fajr.time.dayKey)", content: content, at: fire)]
    }

    @MainActor
    private func weeklyRequests(day: [PrayerTime], settings: AppSettings, now: Date) -> [UNNotificationRequest] {
        let wanted = settings.weeklyReminders
        guard let any = day.first else { return [] }
        let weekday = Calendar.current.component(.weekday, from: any.time)   // 1 = Sunday
        let key = any.time.dayKey
        func time(_ name: String) -> Date? { day.first { $0.name == name }?.time }
        var out: [UNNotificationRequest] = []

        if weekday == 6 {
            if wanted.contains(.alKahf), let fajr = time("Fajr") {
                let fire = fajr.addingTimeInterval(30 * 60)
                if fire > now {
                    out.append(request(id: "weekly_kahf_\(key)", content: reminderContent(
                        title: "Surah Al-Kahf",
                        body: "It’s Friday — a light for the week ahead. A good morning to read Al-Kahf."
                    ), at: fire))
                }
            }
            if wanted.contains(.jumuah), let dhuhr = time("Dhuhr") {
                let fire = dhuhr.addingTimeInterval(-60 * 60)
                if fire > now {
                    out.append(request(id: "weekly_jumuah_\(key)", content: reminderContent(
                        title: "Jumuʿah in one hour",
                        body: "Ghusl, your best clothes, and an early walk to the masjid.",
                        level: .timeSensitive
                    ), at: fire))
                }
            }
        }

        // The night before Monday (Sunday) and Thursday (Wednesday).
        if wanted.contains(.mondayThursdayFasts), weekday == 1 || weekday == 4, let isha = time("Isha") {
            let fire = isha.addingTimeInterval(30 * 60)
            if fire > now {
                let dayName = weekday == 1 ? "Monday" : "Thursday"
                out.append(request(id: "weekly_fast_\(key)", content: reminderContent(
                    title: "Fasting tomorrow?",
                    body: "Tomorrow is \(dayName), a day the Prophet ﷺ liked to fast. Set your intention and an alarm for suhoor."
                ), at: fire))
            }
        }
        return out
    }

    /// Hijri dates use the Umm al-Qura calendar, so they can differ by a day from
    /// local moon sighting; the copy says "expected" for that reason.
    @MainActor
    private func hijriRequests(day: [PrayerTime], settings: AppSettings, now: Date) -> [UNNotificationRequest] {
        let wanted = settings.weeklyReminders
        guard wanted.contains(.ramadan) || wanted.contains(.whiteDays),
              let any = day.first,
              let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: any.time) else { return [] }
        let hijri = Calendar(identifier: .islamicUmmAlQura).dateComponents([.month, .day], from: tomorrow)
        let key = any.time.dayKey
        let maghrib = day.first { $0.name == "Maghrib" }?.time
        let isha = day.first { $0.name == "Isha" }?.time
        var out: [UNNotificationRequest] = []

        func add(_ id: String, _ title: String, _ body: String, at fire: Date?) {
            guard let fire, fire > now else { return }
            out.append(request(id: "hijri_\(id)_\(key)", content: reminderContent(title: title, body: body), at: fire))
        }

        if wanted.contains(.ramadan) {
            switch (hijri.month, hijri.day) {
            case (9, 1):
                add("ramadan", "Ramadan is expected tomorrow",
                    "Ramadan Mubarak — make your intention tonight and wake for suhoor.",
                    at: maghrib?.addingTimeInterval(20 * 60))
            case (10, 1):
                add("eidfitr", "Eid al-Fitr is expected tomorrow",
                    "Eid Mubarak — remember zakat al-fitr before the Eid prayer.",
                    at: maghrib?.addingTimeInterval(20 * 60))
            case (12, 10):
                add("eidadha", "Eid al-Adha is expected tomorrow",
                    "Eid Mubarak — takbir from Fajr, and the Eid prayer in the morning.",
                    at: maghrib?.addingTimeInterval(20 * 60))
            default: break
            }
        }
        if wanted.contains(.whiteDays), hijri.day == 13 {
            add("whitedays", "The White Days begin tomorrow",
                "Fasting the 13th, 14th and 15th is like fasting the whole month.",
                at: isha?.addingTimeInterval(30 * 60))
        }
        return out
    }

    private func reminderContent(
        title: String,
        body: String,
        level: UNNotificationInterruptionLevel = .active
    ) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.interruptionLevel = level
        content.threadIdentifier = "kheir-reminders"
        content.categoryIdentifier = Category.reminder
        return content
    }

    // MARK: Helpers

    private func request(id: String, content: UNNotificationContent, at date: Date) -> UNNotificationRequest {
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        )
    }

    private func fireDate(_ request: UNNotificationRequest) -> Date {
        (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture
    }

    @MainActor
    private func enabledPrayerNames(_ settings: AppSettings) -> Set<String> {
        do {
            var names: Set<String> = []
            if settings.fajrNotification { names.insert("Fajr") }
            if settings.sunriseNotification { names.insert("Sunrise") }
            if settings.dhuhrNotification { names.insert("Dhuhr") }
            if settings.asrNotification { names.insert("Asr") }
            if settings.maghribNotification { names.insert("Maghrib") }
            if settings.ishaNotification { names.insert("Isha") }
            return names
        }
    }

    // MARK: Thumbnail

    /// A small paper scene (sky, hills, the prayer's paper icon) attached as the
    /// notification thumbnail. Rendered once per prayer, copied per request
    /// (the system moves attachment files into its own store).
    @MainActor
    private func thumbnailAttachment(for prayer: String) -> UNNotificationAttachment? {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("kheir-thumbs", isDirectory: true)
        let master = dir.appendingPathComponent("\(prayer)-v1.png")
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            if !FileManager.default.fileExists(atPath: master.path) {
                let renderer = ImageRenderer(content: NotificationThumbnail(prayer: prayer))
                renderer.scale = 3
                guard let data = renderer.uiImage?.pngData() else { return nil }
                try data.write(to: master, options: .atomic)
            }
            let copy = dir.appendingPathComponent("\(prayer)-\(UUID().uuidString).png")
            try FileManager.default.copyItem(at: master, to: copy)
            return try UNNotificationAttachment(identifier: "thumb", url: copy, options: nil)
        } catch {
            logger.error("Thumbnail failed for \(prayer): \(error.localizedDescription)")
            return nil
        }
    }
}

// MARK: - Thumbnail view

private struct NotificationThumbnail: View {
    let prayer: String

    private var sky: [Color] {
        switch prayer {
        case "Fajr": [Color(hex: "#1A2744"), Color(hex: "#3A5A7A"), Color(hex: "#D4926B")]
        case "Sunrise": [Color(hex: "#4A7FA5"), Color(hex: "#C4D8E0"), Color(hex: "#F5D5A0")]
        case "Dhuhr": [Color(hex: "#1976A8"), Color(hex: "#5AB8D4"), Color(hex: "#B0E0EC")]
        case "Asr": [Color(hex: "#3A7A9A"), Color(hex: "#8ABAC4"), Color(hex: "#D4A86B")]
        case "Maghrib": [Color(hex: "#8B2E1A"), Color(hex: "#D4694A"), Color(hex: "#F0C88A")]
        default: [Color(hex: "#0A1020"), Color(hex: "#1A2744"), Color(hex: "#2B3560")]
        }
    }

    var body: some View {
        ZStack {
            sky[0]
            Hill(baseline: 0.50, seed: 3).fill(sky[1])
            Hill(baseline: 0.68, seed: 4).fill(sky[2])
            PaperIconView(PaperIcon.forPrayer(prayer), size: 26, animated: false)
                .offset(y: -4)
        }
        .frame(width: 46, height: 46)
    }

    private struct Hill: Shape {
        let baseline: CGFloat
        let seed: Int
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: 0, y: rect.maxY))
            let n = 12
            for k in 0...n {
                let x = rect.width * CGFloat(k) / CGFloat(n)
                let y = rect.height * baseline + CGFloat(sin(Double(k) * 0.9 + Double(seed)) * 1.6)
                p.addLine(to: CGPoint(x: x, y: y))
            }
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.closeSubpath()
            return p
        }
    }
}

// MARK: - Prayer log

/// Prayers marked "I've prayed" from a notification, stored in the App Group
/// (`prayed_log_v1`: `[dayKey: [prayer names]]`) so the app and widgets can read them.
enum PrayerLog {
    private static let key = "prayed_log_v1"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: "group.com.kheir.shared") }

    static func markPrayed(_ prayer: String, on date: Date) {
        guard let defaults else { return }
        var log = defaults.dictionary(forKey: key) as? [String: [String]] ?? [:]
        let day = date.dayKey
        var names = Set(log[day] ?? [])
        names.insert(prayer)
        log[day] = names.sorted()
        // Keep about a month.
        if log.count > 40 {
            for old in log.keys.sorted().prefix(log.count - 40) { log[old] = nil }
        }
        defaults.set(log, forKey: key)
    }

    static func prayed(on date: Date) -> Set<String> {
        Set((defaults?.dictionary(forKey: key) as? [String: [String]])?[date.dayKey] ?? [])
    }
}

// MARK: - Delegate

private final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        if notification.request.content.categoryIdentifier == NotificationService.Category.prayer {
            // The prayer has arrived: let the countdown Live Activity wrap up.
            await PrayerLiveActivityManager.shared.refresh()
        }
        return [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let action = response.actionIdentifier
        let info = response.notification.request.content.userInfo
        let category = response.notification.request.content.categoryIdentifier
        let prayer = info["prayer"] as? String
        let time = (info["time"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()

        await MainActor.run {
            switch action {
            case NotificationService.Action.prayed:
                guard let prayer else { return }
                PrayerLog.markPrayed(prayer, on: time)
                NotificationCenter.default.post(
                    name: .kheirPrayerMarkedPrayed, object: nil,
                    userInfo: ["prayer": prayer, "time": time]
                )
            case NotificationService.Action.snooze:
                guard let prayer else { return }
                Task { await NotificationService.shared.scheduleSnooze(prayer: prayer, time: time) }
            case NotificationService.Action.qibla:
                Self.open("kheir://qibla")
            case UNNotificationDefaultActionIdentifier where category == NotificationService.Category.prayer:
                Self.open("kheir://prayer")
            default:
                break
            }
        }
        await PrayerLiveActivityManager.shared.refresh()
    }

    @MainActor
    private static func open(_ link: String) {
        guard let url = URL(string: link) else { return }
        NotificationService.pendingDeepLink = url
        NotificationCenter.default.post(name: .kheirOpenDeepLink, object: url)
    }
}
