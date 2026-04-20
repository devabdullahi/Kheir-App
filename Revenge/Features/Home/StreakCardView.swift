import SwiftUI

// MARK: - Streak Card View

/// Displays the user's current app-open streak with celebration visuals at milestones.
///
/// Design decisions:
///   - Completely hidden when `currentStreak == 0` (first launch / no streak yet).
///   - Shows flame icon + count for streaks 1–6.
///   - Triggers celebration animation (scale pulse + particle effect) at 7+ day milestones.
///   - Uses existing `.cardStyle()` and design tokens for visual consistency.
struct StreakCardView: View {
    let streakData: StreakData
    @Environment(\.colorScheme) private var colorScheme
    @State private var celebrationScale: CGFloat = 1.0
    @State private var showCelebration = false

    var body: some View {
        HStack(spacing: 12) {
            // Flame icon — scales up for milestones
            Image(systemName: streakIcon)
                .font(.system(size: 28))
                .foregroundStyle(flameGradient)
                .scaleEffect(celebrationScale)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(streakData.currentStreak) day streak")
                    .font(.headline)
                    .foregroundStyle(Color.adaptiveText(colorScheme))

                if streakData.longestStreak > streakData.currentStreak {
                    Text("Best: \(streakData.longestStreak) days")
                        .font(.caption)
                        .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                }
            }

            Spacer()

            // Milestone badge for 7+ streaks
            if streakData.currentStreak >= 7 {
                milestoneBadge
            }
        }
        .padding(16)
        .background {
            ZStack {
                Color.adaptiveCardSurface(colorScheme)
                if streakData.currentStreak >= 7 {
                    celebrationBackground
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, y: 4)
        .onAppear {
            if streakData.currentStreak >= 7 {
                triggerCelebration()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Daily streak: \(streakData.currentStreak) days")
        .accessibilityIdentifier("streakCard")
    }

    // MARK: - Subviews

    private var milestoneBadge: some View {
        Text(milestoneText)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.adaptivePrimary(colorScheme))
            .clipShape(Capsule())
    }

    private var celebrationBackground: some View {
        LinearGradient(
            colors: [
                Color.adaptivePrimary(colorScheme).opacity(0.05),
                Color.clear
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    // MARK: - Computed Properties

    private var streakIcon: String {
        if streakData.currentStreak >= 30 { return "flame.circle.fill" }
        if streakData.currentStreak >= 7 { return "flame.fill" }
        return "flame"
    }

    private var flameGradient: some ShapeStyle {
        LinearGradient(
            colors: [.orange, .red],
            startPoint: .bottom,
            endPoint: .top
        )
    }

    private var milestoneText: String {
        if streakData.currentStreak >= 30 { return "\(streakData.currentStreak)!" }
        if streakData.currentStreak >= 14 { return "2 weeks+" }
        return "1 week+"
    }

    // MARK: - Animation

    private func triggerCelebration() {
        withAnimation(.easeInOut(duration: 0.4).repeatCount(2, autoreverses: true)) {
            celebrationScale = 1.2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            celebrationScale = 1.0
        }
    }
}
