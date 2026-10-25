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

    var body: some View {
        NavigationLink(destination: RoutineView(routineType: routineType)) {
            HStack(spacing: 14) {
                // Progress ring: a thick paper band on a faint pencil track.
                ZStack {
                    Circle()
                        .stroke(Color.adaptiveText(colorScheme).opacity(0.08), lineWidth: 7)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.adaptivePrimary(colorScheme), style: StrokeStyle(lineWidth: 7, lineCap: .butt))
                        .rotationEffect(.degrees(-90))
                        .paperShadow(depth: 0.4)
                        .animation(.open(0.4), value: progress)
                    PaperIconView(routineType == .morning ? .sunrise : .beads, size: 20)
                }
                .frame(width: 48, height: 48)

                HomeCardLabel(
                    overline: routineType == .morning ? "Morning adhkar" : "Evening adhkar",
                    title: routineType.displayName,
                    note: progressLabel
                )

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }
            .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1, seed: 43)
        }
        .buttonStyle(PaperPressStyle())
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
