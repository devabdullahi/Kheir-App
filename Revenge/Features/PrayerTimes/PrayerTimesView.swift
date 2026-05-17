import SwiftUI

struct PrayerTimesView: View {
    @StateObject private var viewModel = PrayerTimesViewModel()
    @StateObject private var skyEngine = SkyEngine()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Full-screen sky background
            DynamicSkyView(skyState: skyEngine.currentState)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.spacingLG) {
                    // Date Header
                    VStack(spacing: 4) {
                        Text(viewModel.gregorianDate)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.6))
                        Text(viewModel.hijriDate)
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(.top, 60)

                    // Next Prayer Countdown
                    if let next = viewModel.nextPrayer {
                        VStack(spacing: 8) {
                            Text(next.name)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(.white)

                            Text(next.timeString)
                                .font(.system(size: 32, weight: .bold, design: .rounded))
                                .foregroundStyle(Color.islamicGold)
                                .monospacedDigit()

                            Text(viewModel.countdownText)
                                .font(.title3)
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.6))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(DesignTokens.cardPadding)
                        .glassmorphismCard(colorScheme)
                    }

                    // Prayer Cards
                    VStack(spacing: DesignTokens.spacingSM) {
                        ForEach(Array(viewModel.prayers.enumerated()), id: \.element.id) { index, prayer in
                            PrayerCardView(
                                prayer: prayer,
                                state: cardState(for: prayer, at: index),
                                colorScheme: colorScheme
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100) // Space for tab bar
            }
        }
        .navigationTitle("Prayer Times")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    private func cardState(for prayer: PrayerTime, at index: Int) -> PrayerCardState {
        guard let nextPrayer = viewModel.nextPrayer else {
            return .future(dimLevel: 0.5)
        }

        if prayer.id == nextPrayer.id {
            let remaining = prayer.time.timeIntervalSince(Date())
            return .current(remaining: max(0, remaining))
        }

        // Prayers before the next prayer are passed
        if prayer.time < Date() && prayer.id != nextPrayer.id {
            return .passed
        }

        // First prayer after next
        let nextIndex = viewModel.prayers.firstIndex(where: { $0.id == nextPrayer.id }) ?? 0
        if index == nextIndex + 1 {
            return .next
        }

        // Future prayers with progressive dimming
        let distance = Double(index - nextIndex)
        let dimLevel = min(1.0, 0.4 + distance * 0.15)
        return .future(dimLevel: dimLevel)
    }
}
