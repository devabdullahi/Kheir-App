import AppIntents

// MARK: - "Mute till athan" (widget-extension copy)
//
// The Live Activity's button needs the intent type here to build the button, but
// a `LiveActivityIntent` is performed in the APP's process. The app has its own
// copy with the same name and shape (Kheir/Core/LiveActivity/MuteUntilAthanIntent.swift)
// whose `perform()` does the work. Keep the two declarations in sync.

struct MuteUntilAthanIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Mute till athan"
    static let description = IntentDescription("Hides the prayer countdown until the athan.")
    static let isDiscoverable = false

    init() {}

    func perform() async throws -> some IntentResult {
        .result()
    }
}
