import SwiftUI

struct PrayerTimesView: View {
    @StateObject private var viewModel = PrayerTimesViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Date Header
                    VStack(spacing: 4) {
                        Text(viewModel.gregorianDate)
                            .font(.subheadline)
                            .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                        Text(viewModel.hijriDate)
                            .font(.headline)
                            .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    }
                    .padding(.top)

                    // Next Prayer Highlight
                    if let next = viewModel.nextPrayer {
                        nextPrayerCard(next)
                    }

                    // All Prayers
                    VStack(spacing: 0) {
                        ForEach(viewModel.prayers) { prayer in
                            prayerRow(prayer)
                            if prayer.id != viewModel.prayers.last?.id {
                                Divider().padding(.horizontal)
                            }
                        }
                    }
                    .background(Color.adaptiveCardSurface(colorScheme))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, y: 4)
                }
                .padding()
            }
            .background(Color.adaptiveBackground(colorScheme).ignoresSafeArea())
            .navigationTitle("Prayer Times")
            .onAppear { viewModel.onAppear() }
            .onDisappear { viewModel.onDisappear() }
        }
    }

    private func nextPrayerCard(_ prayer: PrayerTime) -> some View {
        VStack(spacing: 8) {
            Text(prayer.name)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text(prayer.timeString)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color.adaptivePrimary(colorScheme))

            Text(viewModel.countdownText)
                .font(.title3)
                .monospacedDigit()
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background {
            ZStack {
                Color.adaptiveCardSurface(colorScheme)
                IslamicPatternBackground(colorScheme: colorScheme)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, y: 4)
    }

    private func prayerRow(_ prayer: PrayerTime) -> some View {
        HStack {
            Image(systemName: prayer.icon)
                .font(.title3)
                .foregroundStyle(prayer.isNext ? Color.adaptivePrimary(colorScheme) : Color.adaptiveSecondaryText(colorScheme))
                .frame(width: 30)

            Text(prayer.name)
                .font(.body)
                .fontWeight(prayer.isNext ? .semibold : .regular)
                .foregroundStyle(prayer.isNext ? Color.adaptivePrimary(colorScheme) : Color.adaptiveText(colorScheme))

            Spacer()

            Text(prayer.timeString)
                .font(.body)
                .monospacedDigit()
                .fontWeight(prayer.isNext ? .semibold : .regular)
                .foregroundStyle(prayer.isNext ? Color.adaptivePrimary(colorScheme) : Color.adaptiveText(colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(prayer.isNext ? Color.adaptivePrimary(colorScheme).opacity(0.08) : .clear)
    }
}
