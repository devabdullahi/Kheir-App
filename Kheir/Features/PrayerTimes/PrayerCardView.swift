import SwiftUI

// MARK: - PrayerCardState

/// Describes the temporal relationship of a prayer to the current moment.
enum PrayerCardState: Equatable {
    /// Prayer has already passed.
    case passed
    /// The prayer whose time we are in now; `remaining` is seconds until the next one.
    case current(remaining: TimeInterval)
    /// The very next prayer (the one being counted down to).
    case next
    /// A later prayer today; `dimLevel` ∈ [0, 1] grows with distance.
    case future(dimLevel: Double)
}

// MARK: - PrayerCardView

/// One prayer as a cut-paper card lying on the sky.
///
/// Depth tells the time: passed prayers lie flat on the table (raised paper,
/// short shadow), the prayer we are in now is lifted highest with a mustard
/// "Now" tag, and the coming prayers sit at card height.
struct PrayerCardView: View {

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    let prayer: PrayerTime
    let state: PrayerCardState
    let colorScheme: ColorScheme
    var seed: Int = 102

    var body: some View {
        HStack(spacing: 12) {
            PaperIconView(PaperIcon.forPrayer(prayer.name), size: isCurrent ? 28 : 24)

            Text(prayer.name)
                .font(.system(size: isCurrent ? 17 : 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.adaptiveText(colorScheme))

            if isCurrent {
                PaperTag(text: "Now", color: PaperInk.mustard, ink: .lightBodyText, seed: 110)
                    .rotationEffect(.degrees(-3))
            }

            Spacer(minLength: 8)

            if let subtitle = subtitleText {
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                    .monospacedDigit()
            }

            Text(formattedTime)
                .font(.system(size: 16, weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.adaptiveText(colorScheme).opacity(isPassed ? 0.7 : 1))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isCurrent ? 16 : 13)
        .paperPiece(surface, material: .card, depth: depth, radius: 16, seed: seed, padding: nil)
        .opacity(isPassed ? 0.85 : 1)
        .rotationEffect(.degrees(tilt))
        .scaleEffect(isCurrent ? 1.015 : 1)
        .contentShape(Rectangle())
        .simultaneousGesture(longPressGesture)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - State styling

    private var isCurrent: Bool {
        if case .current = state { return true }
        return false
    }

    private var isPassed: Bool { state == .passed }

    private var surface: Color {
        isPassed ? Color.adaptiveCardElevated(colorScheme) : Color.adaptiveCardSurface(colorScheme)
    }

    /// Height off the table: flat when passed, highest when current.
    private var depth: CGFloat {
        switch state {
        case .passed: return 0.4
        case .current: return 2.4
        case .next: return 1.3
        case .future: return 1
        }
    }

    private var tilt: Double {
        if isCurrent { return -0.8 }
        return (seeded(seed, salt: 5) - 0.5) * 0.8
    }

    private var subtitleText: String? {
        guard case .current(let remaining) = state, remaining > 0 else { return nil }
        let total = Int(remaining)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m left" : "\(minutes)m left"
    }

    private var formattedTime: String {
        Self.timeFormatter.string(from: prayer.time)
    }

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                Task { @MainActor in HapticManager.shared.mediumTap() }
            }
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        let timeStr = formattedTime
        switch state {
        case .passed:
            return "\(prayer.name), \(timeStr), passed"
        case .current:
            return "\(prayer.name), \(timeStr), now\(subtitleText.map { ", \($0)" } ?? "")"
        case .next:
            return "\(prayer.name), \(timeStr), next prayer"
        case .future:
            return "\(prayer.name), \(timeStr), upcoming"
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Prayer Card States") {
    let now = Date()
    VStack(spacing: 10) {
        PrayerCardView(prayer: PrayerTime(name: "Fajr", time: now.addingTimeInterval(-7200), icon: "sunrise"), state: .passed, colorScheme: .light, seed: 102)
        PrayerCardView(prayer: PrayerTime(name: "Dhuhr", time: now.addingTimeInterval(-1800), icon: "sun.max"), state: .current(remaining: 5_040), colorScheme: .light, seed: 104)
        PrayerCardView(prayer: PrayerTime(name: "Asr", time: now.addingTimeInterval(3600), icon: "sun.min"), state: .next, colorScheme: .light, seed: 105)
        PrayerCardView(prayer: PrayerTime(name: "Maghrib", time: now.addingTimeInterval(7200), icon: "sunset"), state: .future(dimLevel: 0), colorScheme: .light, seed: 106)
    }
    .padding(20)
    .paperBackground()
}
#endif
