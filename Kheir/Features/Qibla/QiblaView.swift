import SwiftUI

struct QiblaView: View {
    @State private var viewModel = QiblaViewModel()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                if viewModel.locationDenied && !viewModel.hasLocation {
                    manualEntryView
                        .quickPlace(0)
                } else {
                    compassContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 100)
        }
        .paperBackground()
        .navigationTitle("Qibla")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: MasjidFinderView(isPushed: true)) {
                    PaperIconView(.masjid, size: 24)
                }
                .accessibilityLabel("Find Nearby Masjid")
            }
        }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    // MARK: - Compass

    @ViewBuilder
    private var compassContent: some View {
        if viewModel.needsCalibration {
            calibrationBanner
                .quickPlace(0)
        }

        PaperCompassDial(
            heading: viewModel.compassHeading,
            needleAngle: viewModel.rotationAngle
        )
        .padding(.vertical, 12)
        .quickPlace(1)

        VStack(spacing: 4) {
            Text(viewModel.hasLocation ? bearingDegrees : "—")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(Color.adaptiveText(colorScheme))
                .monospacedDigit()
            Text(viewModel.hasLocation ? "\(bearingCardinal) · Point your device toward the Kaaba indicator" : "Finding your location…")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1, seed: 91)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Qibla bearing \(viewModel.bearingText)")
        .quickPlace(2)

        NavigationLink(destination: MasjidFinderView(isPushed: true)) {
            PaperButtonLabel(title: "Find Nearby Masjid", icon: .masjid, seed: 92)
                .rotationEffect(.degrees(-0.5))
        }
        .buttonStyle(PaperPressStyle())
        .quickPlace(3)
    }

    private var bearingDegrees: String {
        String(format: "%.0f°", viewModel.qiblaBearing)
    }

    private var bearingCardinal: String {
        QiblaService.cardinalDirection(for: viewModel.qiblaBearing)
    }

    // MARK: - Calibration Banner

    private var calibrationBanner: some View {
        HStack(spacing: 10) {
            PaperIconView(.compass, size: 24)
            Text("Move your device in a figure-8 motion to calibrate the compass")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.lightBodyText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperPiece(PaperInk.mustard, material: .construction, depth: 0.8, edge: .torn, radius: 6, seed: 93, padding: 12)
    }

    // MARK: - Manual Entry Fallback

    private var manualEntryView: some View {
        VStack(spacing: 16) {
            PaperIconView(.pin, size: 40)

            Text("Location access is required for Qibla direction.")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.adaptiveText(colorScheme))

            Text("Enter your city manually:")
                .font(.subheadline)
                .foregroundStyle(Color.adaptiveSecondaryText(colorScheme))

            HStack(spacing: 10) {
                TextField("City name", text: $viewModel.manualCity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .paperPiece(Color.adaptiveCardElevated(colorScheme), material: .card, depth: 0.3, radius: 10, seed: 95, padding: nil)

                Button {
                    viewModel.searchCity()
                } label: {
                    Text("Find")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.lightCardSurface)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .paperPiece(.lightPrimary, material: .construction, depth: 1, radius: 10, seed: 96, padding: nil)
                }
                .buttonStyle(PaperPressStyle())
            }

            if viewModel.hasLocation {
                Text(viewModel.bearingText)
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
            }
        }
        .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1.2, seed: 94)
    }
}

// MARK: - Paper Compass Dial

/// Layered card discs pinned at the centre with a brass brad. The dial turns
/// with the heading; the cut-paper arrow swings to the Kaaba.
///
/// Follow-through: the arrow body follows its target over ~0.45s; the Kaaba tag
/// at its tip trails the body by ~90ms at about half strength, so when the arrow
/// swings the tip lags and then catches up (delay, not a bouncy spring).
struct PaperCompassDial: View {
    let heading: Double
    let needleAngle: Double

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Continuous (unwrapped) angles so a turn from 359° to 1° goes the short way.
    @State private var dialAngle: Double = 0
    @State private var arrowAngle: Double = 0
    @State private var tipAngle: Double = 0

    private let size: CGFloat = 260

    var body: some View {
        ZStack {
            // Base disc
            Circle()
                .fill(Color.adaptiveCardSurface(scheme))
                .overlay(PaperGrain(material: .card, seed: 401, dark: scheme == .dark).clipShape(Circle()))
                .paperShadow(depth: 1.4)

            // Rotating face: inner disc, ticks and cardinal letters
            ZStack {
                Circle()
                    .fill(Color.adaptiveCardElevated(scheme))
                    .overlay(PaperGrain(material: .construction, seed: 402, dark: scheme == .dark).clipShape(Circle()))
                    .padding(18)
                    .paperShadow(depth: 0.4)

                ForEach(0..<36, id: \.self) { tick in
                    Capsule()
                        .fill(Color.adaptiveSecondaryText(scheme).opacity(tick.isMultiple(of: 9) ? 0.8 : 0.35))
                        .frame(width: tick.isMultiple(of: 9) ? 2.5 : 1.5, height: tick.isMultiple(of: 9) ? 10 : 6)
                        .offset(y: -(size / 2 - 26))
                        .rotationEffect(.degrees(Double(tick) * 10))
                }

                ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { index, letter in
                    Text(letter)
                        .font(.system(size: 17, weight: .black, design: .rounded))
                        .foregroundStyle(index == 0 ? Color.paperTerracotta : Color.adaptiveSecondaryText(scheme))
                        .rotationEffect(.degrees(Double(-index) * 90 + dialAngle))
                        .offset(y: -(size / 2 - 48))
                        .rotationEffect(.degrees(Double(index) * 90))
                }
            }
            .rotationEffect(.degrees(-dialAngle))

            // The cut-paper arrow and its Kaaba tag
            ZStack {
                PaperArrow()
                    .frame(width: 30, height: 150)
                    .offset(y: -22)
                    .shadow(color: .black.opacity(0.28), radius: 1.5, x: 1.5, y: 3)
                KaabaTag()
                    .offset(y: -108)
                    .rotationEffect(.degrees(tipAngle - arrowAngle))
            }
            .rotationEffect(.degrees(arrowAngle))

            BrassBrad(size: 15)
        }
        .frame(width: size, height: size)
        .onAppear {
            dialAngle = heading
            arrowAngle = needleAngle
            tipAngle = needleAngle
        }
        .onChange(of: heading) { _, new in
            let target = dialAngle + Self.shortest(from: dialAngle, to: new)
            withAnimation(reduceMotion ? nil : .travel(0.35)) { dialAngle = target }
        }
        .onChange(of: needleAngle) { _, new in
            let target = arrowAngle + Self.shortest(from: arrowAngle, to: new)
            withAnimation(reduceMotion ? nil : .travel(0.45)) { arrowAngle = target }
            // The tip trails the body: a moment later and a little slower.
            withAnimation(reduceMotion ? nil : .travel(0.6).delay(0.09)) { tipAngle = target }
        }
        .accessibilityElement()
        .accessibilityLabel("Qibla compass")
    }

    /// Signed shortest turn from `a` to `b`, in degrees (-180…180].
    static func shortest(from a: Double, to b: Double) -> Double {
        var d = (b - a).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d <= -180 { d += 360 }
        return d
    }
}

/// A two-piece cut-paper arrow: leaf-green head, kraft tail.
private struct PaperArrow: View {
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            let mid = h * 0.62
            var head = Path()
            head.move(to: CGPoint(x: w / 2, y: 0))
            head.addLine(to: CGPoint(x: w, y: mid))
            head.addLine(to: CGPoint(x: w / 2, y: mid + h * 0.06))
            head.addLine(to: CGPoint(x: 0, y: mid))
            head.closeSubpath()
            ctx.fill(head, with: .color(.lightPrimary))
            // a crease down the middle catches the lamp on one side
            var crease = Path()
            crease.move(to: CGPoint(x: w / 2, y: 0))
            crease.addLine(to: CGPoint(x: 0, y: mid))
            crease.addLine(to: CGPoint(x: w / 2, y: mid + h * 0.06))
            crease.closeSubpath()
            ctx.fill(crease, with: .color(.white.opacity(0.12)))

            var tail = Path()
            tail.move(to: CGPoint(x: w / 2, y: mid + h * 0.06))
            tail.addLine(to: CGPoint(x: w * 0.82, y: mid))
            tail.addLine(to: CGPoint(x: w / 2, y: h))
            tail.addLine(to: CGPoint(x: w * 0.18, y: mid))
            tail.closeSubpath()
            ctx.fill(tail, with: .color(.paperKraft))
        }
        .accessibilityHidden(true)
    }
}

/// A tiny Kaaba cut from black card with a mustard band.
private struct KaabaTag: View {
    var body: some View {
        ZStack(alignment: .top) {
            Rectangle().fill(Color(hex: "#2B2118"))
            Rectangle().fill(Color.islamicGold).frame(height: 3.5).padding(.top, 4.5)
        }
        .frame(width: 20, height: 20)
        .clipShape(CutShape(cornerRadius: 1.5, seed: 403))
        .shadow(color: .black.opacity(0.35), radius: 0.8, x: 0.8, y: 1.5)
        .accessibilityHidden(true)
    }
}
