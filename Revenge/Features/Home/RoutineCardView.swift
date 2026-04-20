import SwiftUI

// MARK: - RoutineCardView

/// Compact home-screen card for the contextual morning or evening spiritual routine.
///
/// Visibility rules:
///   - Morning card (Fajr → Dhuhr): shown in the first half of the day.
///   - Evening card (Maghrib → Fajr): shown in the second half of the day.
///   - The current hour drives the decision; prayer-time precision is not required here
///     because the card is a convenience entry point, not a strict prayer schedule.
struct RoutineCardView: View {
    let routineType: RoutineType
    let progress: Double               // 0.0–1.0, supplied by HomeViewModel

    @Environment(\.colorScheme) private var colorScheme
    @State private var isNavigating = false

    var body: some View {
        NavigationLink(destination: RoutineView(routineType: routineType)) {
            HStack(spacing: 16) {
                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color.adaptivePrimary(colorScheme).opacity(0.2), lineWidth: 4)
                        .frame(width: 52, height: 52)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.adaptivePrimary(colorScheme), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 52, height: 52)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.4), value: progress)

                    Image(systemName: routineType.systemImage)
                        .font(.system(size: 20))
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(routineType.displayName)
                        .font(.headline)
                        .foregroundStyle(Color.adaptiveText(colorScheme))

                    Text(progressLabel)
                        .font(.subheadline)
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }
            .padding(16)
            .background {
                ZStack {
                    Color.adaptiveCardSurface(colorScheme)
                    if progress >= 1.0 {
                        completedBackground
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(routineType.displayName). \(progressLabel). Tap to open.")
        .accessibilityIdentifier("routineCard_\(routineType.rawValue)")
    }

    // MARK: - Computed

    private var progressLabel: String {
        if progress >= 1.0 { return "Completed — Alhamdulillah" }
        if progress == 0    { return routineType.subtitle }
        let pct = Int(progress * 100)
        return "\(pct)% complete"
    }

    private var completedBackground: some View {
        LinearGradient(
            colors: [Color.adaptivePrimary(colorScheme).opacity(0.08), Color.clear],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - RoutineTimeHelper

/// Returns the `RoutineType` that should be shown on the Home screen right now,
/// based on the current hour.  Morning (04:00–11:59), Evening (12:00–03:59).
struct RoutineTimeHelper {
    static func currentRoutineType() -> RoutineType {
        let hour = Calendar.current.component(.hour, from: Date())
        return (hour >= 4 && hour < 12) ? .morning : .evening
    }
}
