import SwiftUI

struct QiblaView: View {
    @StateObject private var viewModel = QiblaViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                Color.adaptiveBackground(colorScheme).ignoresSafeArea()

                if viewModel.locationDenied && !viewModel.hasLocation {
                    manualEntryView
                } else {
                    compassView
                }
            }
            .navigationTitle("Qibla")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: MasjidFinderView()) {
                        Image(systemName: "building.columns")
                            .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    }
                    .accessibilityLabel("Find Nearby Masjid")
                }
            }
            .onAppear { viewModel.onAppear() }
            .onDisappear { viewModel.onDisappear() }
        }
    }

    // MARK: - Compass View
    private var compassView: some View {
        VStack(spacing: 24) {
            if viewModel.needsCalibration {
                calibrationBanner
            }

            Spacer()

            // Compass
            ZStack {
                // Outer ring with cardinal directions
                Circle()
                    .stroke(Color.adaptiveSecondaryText(colorScheme).opacity(0.3), lineWidth: 2)
                    .frame(width: 280, height: 280)

                // Cardinal direction labels
                ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { index, direction in
                    Text(direction)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(direction == "N" ? Color.adaptivePrimary(colorScheme) : Color.adaptiveText(colorScheme))
                        .offset(y: -130)
                        .rotationEffect(.degrees(Double(index) * 90))
                }
                .rotationEffect(.degrees(-viewModel.compassHeading))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.compassHeading)

                // Tick marks
                ForEach(0..<72, id: \.self) { tick in
                    Rectangle()
                        .fill(tick % 9 == 0 ? Color.adaptiveText(colorScheme) : Color.adaptiveSecondaryText(colorScheme).opacity(0.4))
                        .frame(width: tick % 9 == 0 ? 2 : 1, height: tick % 9 == 0 ? 12 : 6)
                        .offset(y: -134)
                        .rotationEffect(.degrees(Double(tick) * 5))
                }
                .rotationEffect(.degrees(-viewModel.compassHeading))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.compassHeading)

                // Qibla direction indicator
                VStack(spacing: 0) {
                    Image(systemName: "building.columns.fill")
                        .font(.title)
                        .foregroundStyle(Color.islamicGold)
                    Rectangle()
                        .fill(Color.islamicGold)
                        .frame(width: 3, height: 80)
                }
                .offset(y: -70)
                .rotationEffect(.degrees(viewModel.rotationAngle))
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.rotationAngle)

                // Center circle
                Circle()
                    .fill(Color.adaptivePrimary(colorScheme))
                    .frame(width: 12, height: 12)
            }

            // Bearing text
            Text(viewModel.bearingText)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(Color.adaptivePrimary(colorScheme))

            Text("Point your device toward the Kaaba indicator")
                .font(.caption)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))

            Spacer()
        }
        .padding()
    }

    // MARK: - Calibration Banner
    private var calibrationBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text("Move your device in a figure-8 motion to calibrate the compass")
                .font(.caption)
                .foregroundStyle(Color.adaptiveText(colorScheme))
        }
        .padding(12)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Manual Entry Fallback
    private var manualEntryView: some View {
        VStack(spacing: 20) {
            Image(systemName: "location.slash")
                .font(.system(size: 48))
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))

            Text("Location access is required for Qibla direction.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("Enter your city manually:")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))

            HStack {
                TextField("City name", text: $viewModel.manualCity)
                    .textFieldStyle(.roundedBorder)

                Button("Find") {
                    viewModel.searchCity()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.adaptivePrimary(colorScheme))
            }
            .padding(.horizontal, 40)

            if viewModel.hasLocation {
                Text(viewModel.bearingText)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
            }
        }
    }
}
