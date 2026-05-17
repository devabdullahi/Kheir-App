import SwiftUI

// MARK: - PrayerCardState

/// Describes the temporal relationship of a prayer to the current moment.
enum PrayerCardState: Equatable {
    /// Prayer has already passed.
    case passed
    /// This is the active prayer; `remaining` is seconds until it ends.
    case current(remaining: TimeInterval)
    /// The very next prayer after the current one.
    case next
    /// A future prayer; `dimLevel` ∈ [0, 1] drives progressive fade (0.6 → 0.4 opacity).
    case future(dimLevel: Double)
}

// MARK: - PrayerCardView

/// State-aware glassmorphism card for a single prayer time.
///
/// Designed to render over the dynamic sky background found in the Sacred Garden
/// home experience. Each state has distinct visual weight so the user can scan
/// the prayer list at a glance without reading labels.
///
/// Usage:
/// ```swift
/// PrayerCardView(prayer: fajr, state: .current(remaining: 3420), colorScheme: colorScheme)
/// ```
struct PrayerCardView: View {

    let prayer: PrayerTime
    let state: PrayerCardState
    let colorScheme: ColorScheme

    // MARK: - Body

    var body: some View {
        cardContent
            .pressScale(0.97)
            .simultaneousGesture(longPressGesture)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityDescription)
    }

    // MARK: - Card Content

    private var cardContent: some View {
        ZStack(alignment: .leading) {
            // Glassmorphism base
            cardBackground

            // Gold left-edge glow — current state only
            if case .current = state {
                currentGoldGlow
            }

            // Row layout
            HStack(spacing: 0) {
                indicatorCircle
                    .padding(.trailing, 12)

                nameStack

                Spacer(minLength: 0)

                timeLabel
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
        }
        .opacity(cardOpacity)
        .shadow(
            color: shadowColor,
            radius: shadowRadius,
            x: 0,
            y: 0
        )
    }

    // MARK: - Background

    @ViewBuilder
    private var cardBackground: some View {
        let surface = Color(red: 0.051, green: 0.122, blue: 0.102)

        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(.ultraThinMaterial)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(surface.opacity(surfaceOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(borderColor, lineWidth: 1)
            }
    }

    // MARK: - Left Gold Glow (current only)

    private var currentGoldGlow: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color(red: 0.831, green: 0.659, blue: 0.278).opacity(0.15),
                            .clear
                        ],
                        center: .leading,
                        startRadius: 0,
                        endRadius: 40
                    )
                )
                .frame(width: 40)
                .clipShape(
                    RoundedRectangle(cornerRadius: cornerRadius)
                )
            Spacer()
        }
    }

    // MARK: - Indicator Circle

    @ViewBuilder
    private var indicatorCircle: some View {
        switch state {
        case .passed:
            Circle()
                .fill(Color(red: 0.133, green: 0.341, blue: 0.235))
                .frame(width: 8, height: 8)

        case .current:
            Circle()
                .fill(Color(red: 0.831, green: 0.659, blue: 0.278))
                .frame(width: 10, height: 10)
                .shadow(
                    color: Color(red: 0.831, green: 0.659, blue: 0.278).opacity(0.4),
                    radius: 8,
                    x: 0,
                    y: 0
                )

        case .next:
            Circle()
                .strokeBorder(
                    Color(red: 0.910, green: 0.863, blue: 0.784).opacity(0.30),
                    lineWidth: 1.5
                )
                .frame(width: 8, height: 8)

        case .future:
            Circle()
                .strokeBorder(
                    Color(red: 0.910, green: 0.863, blue: 0.784).opacity(0.175),
                    lineWidth: 1
                )
                .frame(width: 8, height: 8)
        }
    }

    // MARK: - Name + Subtitle Stack

    private var nameStack: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(prayer.name)
                .font(.system(size: nameFontSize, weight: nameFontWeight))
                .foregroundStyle(Color(red: 0.910, green: 0.863, blue: 0.784))

            if let subtitle = subtitleText {
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.831, green: 0.659, blue: 0.278).opacity(0.70))
            }
        }
    }

    // MARK: - Time Label

    private var timeLabel: some View {
        HStack(spacing: 6) {
            Text(formattedTime)
                .font(.system(size: 15, weight: .regular).monospacedDigit())
                .foregroundStyle(Color(red: 0.910, green: 0.863, blue: 0.784).opacity(timeLabelOpacity))

            if case .passed = state {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Color(red: 0.133, green: 0.341, blue: 0.235))
            }
        }
    }

    // MARK: - Gestures

    private var longPressGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                Task { @MainActor in
                    HapticManager.shared.mediumTap()
                }
            }
    }

    // MARK: - Computed Styling

    private var cornerRadius: CGFloat {
        if case .current = state { return 18 }
        return 16
    }

    private var horizontalPadding: CGFloat {
        if case .current = state { return 16 }
        return 14
    }

    private var verticalPadding: CGFloat {
        if case .current = state { return 16 }
        return 14
    }

    private var cardOpacity: Double {
        switch state {
        case .passed:
            return 0.4
        case .current, .next:
            return 1.0
        case .future(let dimLevel):
            // dimLevel 0 → 0.6 opacity, dimLevel 1 → 0.4 opacity
            return 0.6 - (0.2 * dimLevel)
        }
    }

    private var surfaceOpacity: Double {
        switch state {
        case .passed:   return 0.40
        case .current:  return 0.70
        case .next:     return 0.55
        case .future(let dimLevel):
            // 0.45 → 0.40 as dimLevel increases
            return 0.45 - (0.05 * dimLevel)
        }
    }

    private var borderColor: Color {
        let green = Color(red: 0.133, green: 0.341, blue: 0.235)
        let gold  = Color(red: 0.831, green: 0.659, blue: 0.278)

        switch state {
        case .passed:
            return green.opacity(0.10)
        case .current:
            return gold.opacity(0.25)
        case .next, .future:
            return Color(red: 0.910, green: 0.863, blue: 0.784).opacity(0.08)
        }
    }

    private var shadowColor: Color {
        if case .current = state {
            return Color(red: 0.831, green: 0.659, blue: 0.278).opacity(0.08)
        }
        return .clear
    }

    private var shadowRadius: CGFloat {
        if case .current = state { return 20 }
        return 0
    }

    private var nameFontSize: CGFloat {
        if case .current = state { return 16 }
        return 15
    }

    private var nameFontWeight: Font.Weight {
        if case .current = state { return .semibold }
        return .regular
    }

    private var timeLabelOpacity: Double {
        switch state {
        case .passed:  return 0.5
        case .current: return 1.0
        case .next:    return 0.85
        case .future:  return 0.6
        }
    }

    /// Subtitle line shown only for the current prayer.
    private var subtitleText: String? {
        guard case .current(let remaining) = state else { return nil }
        let total   = max(0, Int(remaining))
        let hours   = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "Current · \(hours)h \(minutes)m remaining"
        } else {
            return "Current · \(minutes)m remaining"
        }
    }

    // MARK: - Time Formatting

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: prayer.time)
    }

    // MARK: - Accessibility

    private var accessibilityDescription: String {
        let timeStr = formattedTime
        switch state {
        case .passed:
            return "\(prayer.name), \(timeStr), passed"
        case .current:
            let subtitle = subtitleText ?? "current"
            return "\(prayer.name), \(timeStr), \(subtitle)"
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
    ZStack {
        // Simulated sky gradient backdrop
        LinearGradient(
            colors: [
                Color(red: 0.10, green: 0.04, blue: 0.25),
                Color(red: 0.04, green: 0.22, blue: 0.40)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 10) {
                let sampleDate = Date()

                PrayerCardView(
                    prayer: PrayerTime(name: "Fajr",    time: sampleDate.addingTimeInterval(-7200), icon: "sunrise"),
                    state:  .passed,
                    colorScheme: .dark
                )

                PrayerCardView(
                    prayer: PrayerTime(name: "Dhuhr",   time: sampleDate.addingTimeInterval(-1800), icon: "sun.max"),
                    state:  .current(remaining: 5_040),
                    colorScheme: .dark
                )

                PrayerCardView(
                    prayer: PrayerTime(name: "Asr",     time: sampleDate.addingTimeInterval(3600),  icon: "sun.min"),
                    state:  .next,
                    colorScheme: .dark
                )

                PrayerCardView(
                    prayer: PrayerTime(name: "Maghrib", time: sampleDate.addingTimeInterval(7200),  icon: "sunset"),
                    state:  .future(dimLevel: 0.0),
                    colorScheme: .dark
                )

                PrayerCardView(
                    prayer: PrayerTime(name: "Isha",    time: sampleDate.addingTimeInterval(10800), icon: "moon.stars"),
                    state:  .future(dimLevel: 1.0),
                    colorScheme: .dark
                )
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 32)
        }
    }
    .preferredColorScheme(.dark)
}
#endif
