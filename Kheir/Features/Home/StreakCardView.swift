import SwiftUI

// MARK: - Streak Card View

/// The user's app-open streak as a paper plant that grows with the days.
///
/// The plant carries the celebration: it grows a little each day, so there is no
/// badge or pulse here. The card is a raised piece of cardstock.
struct StreakCardView: View {
    let streakData: StreakData
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            plant
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 1) {
                Text(daysText)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .contentTransition(.numericText())
                Text(detailText)
                    .font(.system(size: 12.5, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
            }

            Spacer(minLength: 0)
        }
        .paperPiece(Color.adaptiveCardElevated(colorScheme), material: .card, depth: 1, seed: 42)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily streak: \(streakData.currentStreak) days. Best \(best) days.")
        .accessibilityIdentifier("streakCard")
    }

    @ViewBuilder
    private var plant: some View {
        StreakPlantView(days: streakData.currentStreak, size: 48)
    }

    private var best: Int { max(streakData.longestStreak, streakData.currentStreak) }

    private var daysText: String {
        streakData.currentStreak == 1 ? "1 day" : "\(streakData.currentStreak) days"
    }

    private var detailText: String {
        let stage = streakData.currentStreak >= 30 ? "in bloom" : "growing"
        return streakData.currentStreak >= best ? "\(stage) · your best yet" : "\(stage) · best \(best)"
    }
}
