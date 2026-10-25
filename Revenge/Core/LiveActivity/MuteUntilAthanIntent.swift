import AppIntents

// MARK: - "Mute till athan" (app copy)
//
// Button in the prayer Live Activity (Dynamic Island expanded). A
// `LiveActivityIntent` runs in the app's process, so this copy does the work.
// The widget extension has a copy with the same name and shape
// (KheirWidget/MuteUntilAthanIntent.swift) used only to build the button.

struct MuteUntilAthanIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mute till athan"
    static let description = IntentDescription("Hides the prayer countdown until the athan.")
    static let isDiscoverable = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await PrayerLiveActivityManager.shared.muteUntilAthan()
        return .result()
    }
}
