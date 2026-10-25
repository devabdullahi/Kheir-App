import SwiftUI

struct PrayerTimesView: View {
    @State private var viewModel = PrayerTimesViewModel()
    @State private var skyEngine = SkyEngine()
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

                    // Empty-state: visible reason why prayers aren't loading
                    // (location denied, network down, manual city typo'd, etc.)
                    if viewModel.prayers.isEmpty {
                        EmptyPrayerStateView(
                            statusMessage: viewModel.statusMessage,
                            isLoading: viewModel.isLoading || !viewModel.hasAttemptedLoad,
                            retry: { viewModel.retry() }
                        )
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100) // Space for tab bar
            }
        }
        .navigationTitle("Prayer Times")
        .toolbarTitleDisplayMode(.inline)
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

// MARK: - Empty State
//
// Shown when `viewModel.prayers` is empty so the user isn't staring at a blank
// sky background wondering what went wrong. Always pairs a status message with
// a manual retry button — the previous version silently dropped every failure.
struct EmptyPrayerStateView: View {
    let statusMessage: String
    let isLoading: Bool
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: isLoading ? "icloud.and.arrow.down" : "location.slash")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Color(red: 0.910, green: 0.863, blue: 0.784).opacity(0.7))

            Text(isLoading ? "Loading prayer times…" : (statusMessage.isEmpty ? "Prayer times unavailable" : statusMessage))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            if !isLoading {
                Button(action: retry) {
                    Text("Retry")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(red: 0.831, green: 0.659, blue: 0.278))
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .overlay(
                            Capsule().stroke(
                                Color(red: 0.831, green: 0.659, blue: 0.278).opacity(0.6),
                                lineWidth: 1
                            )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
