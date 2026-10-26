import ActivityKit
import Foundation
import os

// MARK: - Prayer Live Activity manager
//
// Shows a countdown Live Activity for the next prayer whose notification is on,
// starting 15 minutes before it. Reads times from `SharedPrayerSchedule` (written
// by `NotificationService` whenever prayers are scheduled) and the per-prayer
// toggles in `AppSettings`.
//
// Limits (ActivityKit, no push server):
// - Activities can only be requested while the app is in the foreground. On
//   iOS 26 we use a *scheduled* request (`start:`), so opening the app any time
//   before the window queues the activity to appear 15 minutes before the prayer
//   even if the app is closed by then. Only the next prayer is queued.
// - The app cannot run at prayer time, so it cannot end the activity exactly
//   then. The activity goes stale at prayer time (the UI flips to "… — now") and
//   is ended the next time `refresh()` runs, or by the system after 8 hours.
//   Push-to-start / push updates would remove both limits later.
//
// Call `refresh()` when the app becomes active and after prayer times change
// (NotificationService already calls it after scheduling). Call
// `setForeground(true/false)` on scene-phase changes to keep the paper sun moving
// along its strip while the app is open.

@MainActor
final class PrayerLiveActivityManager {
    static let shared = PrayerLiveActivityManager()

    /// How long before the prayer the countdown appears.
    static let leadTime: TimeInterval = 15 * 60

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Kheir", category: "PrayerLiveActivity")
    private let mutedKey = "liveActivityMutedUntil"
    private var tickTask: Task<Void, Never>?

    private init() {}

    typealias Content = ActivityContent<PrayerCountdownAttributes.ContentState>

    // MARK: Public API

    /// Ends finished activities and starts (or schedules) the next one.
    func refresh(now: Date = Date()) async {
        await endFinished(now: now)

        guard ActivityAuthorizationInfo().areActivitiesEnabled,
              let target = nextTarget(after: now) else { return }

        let id = target.attributes.prayerID
        let content = Content(state: target.state, staleDate: target.state.prayerTime, relevanceScore: 50)

        // Already showing or queued: just nudge the sun along.
        if await Self.updateIfPresent(id: id, content: content) { return }
        // Only one Kheir countdown at a time.
        await Self.end(where: { _ in true })

        let start = target.state.prayerTime.addingTimeInterval(-Self.leadTime)
        do {
            if start <= now {
                _ = try Activity.request(attributes: target.attributes, content: content, pushType: nil)
            } else {
                let alert = AlertConfiguration(
                    title: "\(target.state.prayerName) in 15 minutes",
                    body: "Time to get ready for \(target.state.prayerName).",
                    sound: .default
                )
                _ = try Activity.request(
                    attributes: target.attributes,
                    content: content,
                    pushType: nil,
                    style: .standard,
                    alertConfiguration: alert,
                    start: start
                )
            }
        } catch {
            logger.error("Live Activity request failed: \(error.localizedDescription)")
        }
    }

    /// Starts the countdown to the next enabled prayer right now, whatever the time
    /// (for trying the Live Activity from Settings). Returns a reason when it can't.
    func startNow(now: Date = Date()) async -> String? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return "Live Activities are off for Kheir. Turn them on in Settings › Kheir."
        }
        guard let target = nextTarget(after: now) else {
            return "No upcoming prayer with its athan on. Set a location and turn on an athan."
        }
        await Self.end(where: { _ in true })
        let content = Content(state: target.state, staleDate: target.state.prayerTime, relevanceScore: 50)
        do {
            _ = try Activity.request(attributes: target.attributes, content: content, pushType: nil)
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    /// While the app is in the foreground, re-render the activity once a minute so
    /// the paper sun moves along the strip. Stops when the app goes to background.
    func setForeground(_ active: Bool) {
        tickTask?.cancel()
        tickTask = nil
        guard active else { return }
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    /// "Mute till athan": hide the countdown and don't bring it back before the
    /// athan of the prayer it was counting down to. The athan itself still plays.
    func muteUntilAthan() async {
        let until = Activity<PrayerCountdownAttributes>.activities.map(\.content.state.prayerTime).max() ?? Date()
        UserDefaults.standard.set(until.timeIntervalSince1970, forKey: mutedKey)
        await Self.end(where: { _ in true })
    }

    /// Ends every Kheir activity (e.g. when the user turns the feature off).
    func endAll() async {
        await Self.end(where: { _ in true })
    }

    // MARK: Internals

    private func endFinished(now: Date) async {
        await Self.endFinished(now: now)
    }

    // ActivityKit's `Activity` is not Sendable, so every call on one happens off
    // the main actor, on activities looked up inside the same function.

    @concurrent
    private nonisolated static func updateIfPresent(id: String, content: Content) async -> Bool {
        guard let current = Activity<PrayerCountdownAttributes>.activities.first(where: { $0.attributes.prayerID == id }) else {
            return false
        }
        if current.activityState == .active || current.activityState == .stale {
            await current.update(content)
        }
        return true
    }

    @concurrent
    private nonisolated static func end(where shouldEnd: @Sendable (PrayerCountdownAttributes.ContentState) -> Bool) async {
        for activity in Activity<PrayerCountdownAttributes>.activities where shouldEnd(activity.content.state) {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    @concurrent
    private nonisolated static func endFinished(now: Date) async {
        for activity in Activity<PrayerCountdownAttributes>.activities {
            let state = activity.content.state
            guard state.prayerTime <= now else { continue }
            // Leave "Maghrib — now" up for a few minutes after the athan.
            let dismissAt = state.prayerTime.addingTimeInterval(10 * 60)
            await activity.end(
                Content(state: state, staleDate: nil),
                dismissalPolicy: dismissAt > now ? .after(dismissAt) : .immediate
            )
        }
    }

    private func nextTarget(after now: Date) -> (attributes: PrayerCountdownAttributes, state: PrayerCountdownAttributes.ContentState)? {
        guard let schedule = SharedPrayerSchedule.load() else { return nil }
        let five = schedule.prayers
            .filter { SharedPrayerSchedule.fivePrayers.contains($0.name) }
            .sorted { $0.time < $1.time }
        let enabled = enabledPrayers()
        let mutedUntil = UserDefaults.standard.double(forKey: mutedKey)

        guard let index = five.firstIndex(where: {
            $0.date > now && enabled.contains($0.name) && $0.time > mutedUntil
        }) else { return nil }
        let next = five[index]
        let previous = index > 0
            ? five[index - 1]
            : SharedPrayer(name: "Isha", time: next.time - 6 * 3600)

        let state = PrayerCountdownAttributes.ContentState(
            prayerName: next.name,
            prayerTime: next.date,
            previousName: previous.name,
            previousTime: previous.date
        )
        return (PrayerCountdownAttributes(prayerID: "\(next.name)-\(next.date.dayKey)"), state)
    }

    private func enabledPrayers() -> Set<String> {
        let s = AppSettings.shared
        var names: Set<String> = []
        if s.fajrNotification { names.insert("Fajr") }
        if s.dhuhrNotification { names.insert("Dhuhr") }
        if s.asrNotification { names.insert("Asr") }
        if s.maghribNotification { names.insert("Maghrib") }
        if s.ishaNotification { names.insert("Isha") }
        return names
    }
}
