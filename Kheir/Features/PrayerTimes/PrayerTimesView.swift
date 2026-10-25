import SwiftUI

/// Today's prayers as paper cards over the full-height paper sky.
struct PrayerTimesView: View {
    @State private var viewModel = PrayerTimesViewModel()
    @State private var skyEngine = SkyEngine()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            DynamicSkyView(skyState: skyEngine.currentState, showsHills: false)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: DesignTokens.spacingLG) {
                    dateHeader
                        .padding(.top, 26)
                        .quickPlace(0)

                    if let next = viewModel.nextPrayer {
                        countdownCard(next)
                            .quickPlace(1)
                    }

                    VStack(spacing: 10) {
                        ForEach(Array(viewModel.prayers.enumerated()), id: \.element.id) { index, prayer in
                            PrayerCardView(
                                prayer: prayer,
                                state: cardState(for: prayer, at: index),
                                colorScheme: colorScheme,
                                seed: 102 + index
                            )
                            .quickPlace(index + 2)
                        }
                    }
                    .padding(.top, 2)

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
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // Space for tab bar
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Prayer Times")
        .toolbarTitleDisplayMode(.inline)
        // The title lives on the plaque; the bar keeps only the back button when pushed.
        .toolbar { ToolbarItem(placement: .principal) { Color.clear.frame(width: 1, height: 1) } }
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            viewModel.onAppear()
            feedSky()
        }
        .onDisappear { viewModel.onDisappear() }
        .onChange(of: viewModel.prayers.map(\.time)) { _, _ in feedSky() }
    }

    // MARK: - Header

    /// Same indigo tissue plaque as Home's countdown, so text stays readable with the
    /// sun and clouds at the same height behind it on both screens.
    private var dateHeader: some View {
        VStack(spacing: 3) {
            Text("PRAYER TIMES")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.8))
            Text(HijriLabel.string())
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
            Text(viewModel.gregorianDate)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
        }
        .shadow(color: .black.opacity(0.28), radius: 0, x: 0, y: 1)
        .padding(.horizontal, 20)
        .padding(.vertical, 9)
        .paperPiece(Color(hex: "#141A33").opacity(0.78), material: .tissue, depth: 0.8, radius: 16, seed: 46, padding: nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private func countdownCard(_ next: PrayerTime) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                PaperIconView(PaperIcon.forPrayer(next.name), size: 26)
                Text(next.name)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
            }
            Text(next.timeString)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(Color.adaptiveGold(colorScheme))
                .monospacedDigit()
            Text("in \(viewModel.countdownText)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(maxWidth: .infinity)
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1.8, seed: 101)
        .rotationEffect(.degrees(-0.4))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Next prayer \(next.name) at \(next.timeString), in \(viewModel.countdownText)")
    }

    // MARK: - State

    private func feedSky() {
        guard !viewModel.prayers.isEmpty else { return }
        skyEngine.loadPrayerTimes(viewModel.prayers.map { (name: $0.name, time: $0.time) })
    }

    /// The prayer we are in now is the last one whose time has come; the next
    /// prayer is the one being counted down to.
    private func cardState(for prayer: PrayerTime, at index: Int) -> PrayerCardState {
        let now = Date()
        let currentIndex = viewModel.prayers.lastIndex(where: { $0.time <= now })

        if index == currentIndex {
            let remaining = viewModel.nextPrayer.map { $0.time.timeIntervalSince(now) } ?? 0
            return .current(remaining: max(0, remaining))
        }
        if prayer.time <= now {
            return .passed
        }
        if prayer.id == viewModel.nextPrayer?.id {
            return .next
        }
        let nextIndex = viewModel.prayers.firstIndex(where: { $0.id == viewModel.nextPrayer?.id }) ?? index
        let distance = Double(max(0, index - nextIndex))
        return .future(dimLevel: min(1.0, distance * 0.25))
    }
}

// MARK: - Empty State
//
// Shown when `viewModel.prayers` is empty so the user isn't staring at a blank
// sky wondering what went wrong. Always pairs a status message with a manual
// retry button.
struct EmptyPrayerStateView: View {
    let statusMessage: String
    let isLoading: Bool
    let retry: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 12) {
            PaperIconView(isLoading ? .clock : .pin, size: 34)

            Text(isLoading ? "Loading prayer times…" : (statusMessage.isEmpty ? "Prayer times unavailable" : statusMessage))
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            if !isLoading {
                Button(action: retry) {
                    Text("Retry")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.lightCardSurface)
                        .padding(.horizontal, 26)
                        .padding(.vertical, 10)
                        .paperPiece(.lightPrimary, material: .construction, depth: 1, radius: 12, seed: 118, padding: nil)
                }
                .buttonStyle(PaperPressStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1.2, seed: 117)
    }
}
