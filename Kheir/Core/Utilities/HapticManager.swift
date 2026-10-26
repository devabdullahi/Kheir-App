import UIKit

/// Centralized haptic feedback manager for the Sacred Garden experience.
/// Pre-warms generators on init for zero-latency feedback.
@MainActor
final class HapticManager: Sendable {
    static let shared = HapticManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    private init() {
        prepareAll()
    }

    private func prepareAll() {
        lightImpact.prepare()
        mediumImpact.prepare()
        softImpact.prepare()
        notification.prepare()
        selection.prepare()
    }

    // MARK: - Tab switch, bookmark toggle, card tap
    func lightTap() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }

    // MARK: - Share action, notification toggle
    func mediumTap() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }

    // MARK: - Scroll snap, page turn, pull-to-refresh threshold
    func softTap() {
        softImpact.impactOccurred()
        softImpact.prepare()
    }

    // MARK: - Prayer complete, streak milestone
    func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }

    // MARK: - Picker change, Qari selection
    func selectionChanged() {
        selection.selectionChanged()
        selection.prepare()
    }
}
