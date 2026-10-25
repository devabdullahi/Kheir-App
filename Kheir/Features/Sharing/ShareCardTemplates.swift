import SwiftUI

// MARK: - Branding Watermark

private struct KheirWatermark: View {
    let foreground: Color

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: 11, weight: .medium))
            Text("Kheir")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(foreground.opacity(0.55))
    }
}

// MARK: - Ornate Divider

private struct OrnateDivider: View {
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            line
            diamond
            line
        }
    }

    private var line: some View {
        Rectangle()
            .fill(color.opacity(0.5))
            .frame(height: 1)
    }

    private var diamond: some View {
        Image(systemName: "diamond.fill")
            .font(.system(size: 6))
            .foregroundStyle(color.opacity(0.7))
    }
}

// MARK: - Eight-Pointed Star Shape (for geometric border)

private struct StarBorderOverlay: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let patternSize: CGFloat = 60
            let tileColor = color.opacity(0.12)
            for row in 0..<Int(size.height / patternSize) + 1 {
                for col in 0..<Int(size.width / patternSize) + 1 {
                    let x = CGFloat(col) * patternSize
                    let y = CGFloat(row) * patternSize
                    let center = CGPoint(x: x + patternSize / 2, y: y + patternSize / 2)
                    let radius = patternSize * 0.28

                    var path = Path()
                    for i in 0..<8 {
                        let angle = Double(i) * .pi / 4 - .pi / 2
                        let outerPoint = CGPoint(
                            x: center.x + radius * cos(angle),
                            y: center.y + radius * sin(angle)
                        )
                        let innerAngle = angle + .pi / 8
                        let innerPoint = CGPoint(
                            x: center.x + radius * 0.42 * cos(innerAngle),
                            y: center.y + radius * 0.42 * sin(innerAngle)
                        )
                        if i == 0 {
                            path.move(to: outerPoint)
                        } else {
                            path.addLine(to: outerPoint)
                        }
                        path.addLine(to: innerPoint)
                    }
                    path.closeSubpath()
                    context.fill(path, with: .color(tileColor))
                }
            }
        }
    }
}

// MARK: - Minimal Share Card

/// Clean background with centered Arabic text, translation below, subtle branding.
struct MinimalShareCard: View {
    let data: ShareCardData
    let colorScheme: ColorScheme

    private var isStory: Bool { true }

    var body: some View {
        ZStack {
            // Background
            Color.adaptiveBackground(colorScheme)

            // Thin border accent on left edge
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.adaptivePrimary(colorScheme).opacity(0.6))
                    .frame(width: 6)
                Spacer()
            }

            VStack(spacing: 0) {
                Spacer()

                // Type label
                Text(data.type == .ayah ? "Daily Ayah" : "Daily Hadith")
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    .padding(.bottom, 36)

                // Arabic text (if present)
                if let arabic = data.arabicText, !arabic.isEmpty {
                    Text(arabic)
                        .font(.custom("ScheherazadeNew-Regular", size: 52))
                        .environment(\.layoutDirection, .rightToLeft)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptiveText(colorScheme))
                        .padding(.horizontal, 60)
                        .padding(.bottom, 28)
                }

                // Divider
                OrnateDivider(color: Color.adaptivePrimary(colorScheme))
                    .padding(.horizontal, 80)
                    .padding(.bottom, 28)

                // Translation / content
                Text(data.content)
                    .font(.system(size: 28, weight: .light, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .padding(.horizontal, 60)
                    .padding(.bottom, 24)

                // Reference
                Text(data.reference)
                    .font(.system(size: 20, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    .padding(.bottom, 8)

                Spacer()

                // Watermark
                KheirWatermark(foreground: Color.adaptiveText(colorScheme))
                    .padding(.bottom, 48)
            }
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Geometric Share Card

/// Islamic geometric pattern border, content centered on card surface.
struct GeometricShareCard: View {
    let data: ShareCardData
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            // Base background
            Color.adaptiveBackground(colorScheme)

            // Full-bleed geometric pattern
            StarBorderOverlay(color: Color.adaptivePrimary(colorScheme))

            // Inner content panel
            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.adaptiveCardSurface(colorScheme))
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.12),
                                radius: 30, y: 10)

                    VStack(spacing: 28) {
                        // Type badge
                        Text(data.type == .ayah ? "AYAH" : "HADITH")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .tracking(5)
                            .foregroundStyle(Color.adaptivePrimary(colorScheme))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color.adaptivePrimary(colorScheme).opacity(0.1))
                            )

                        // Arabic text
                        if let arabic = data.arabicText, !arabic.isEmpty {
                            Text(arabic)
                                .font(.custom("ScheherazadeNew-Regular", size: 44))
                                .environment(\.layoutDirection, .rightToLeft)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(Color.adaptiveText(colorScheme))
                        }

                        OrnateDivider(color: Color.adaptivePrimary(colorScheme))
                            .padding(.horizontal, 30)

                        // Content
                        Text(data.content)
                            .font(.system(size: 24, weight: .light, design: .serif))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Color.adaptiveText(colorScheme))

                        // Reference
                        Text(data.reference)
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.adaptivePrimary(colorScheme))
                    }
                    .padding(50)
                }
                .padding(.horizontal, 50)

                Spacer()

                KheirWatermark(foreground: Color.adaptiveText(colorScheme))
                    .padding(.bottom, 48)
            }
        }
    }
}

// MARK: - Calligraphy Share Card

/// Large Arabic text as hero element, ornate top/bottom dividers, small translation.
struct CalligraphyShareCard: View {
    let data: ShareCardData
    let colorScheme: ColorScheme

    var body: some View {
        ZStack {
            // Dark parchment-like background
            (colorScheme == .dark
                ? Color(red: 0.06, green: 0.07, blue: 0.12)
                : Color(red: 0.96, green: 0.93, blue: 0.86))

            VStack(spacing: 0) {
                // Top ornate divider band
                topBand

                Spacer()

                // Hero Arabic text
                if let arabic = data.arabicText, !arabic.isEmpty {
                    Text(arabic)
                        .font(.custom("ScheherazadeNew-Regular", size: 68))
                        .environment(\.layoutDirection, .rightToLeft)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.adaptivePrimary(colorScheme))
                        .padding(.horizontal, 50)
                        .padding(.bottom, 36)
                }

                // Translation
                Text(data.content)
                    .font(.system(size: 22, weight: .light, design: .serif))
                    .multilineTextAlignment(.center)
                    .italic()
                    .foregroundStyle(Color.adaptiveText(colorScheme).opacity(0.85))
                    .padding(.horizontal, 60)
                    .padding(.bottom, 20)

                // Reference
                Text(data.reference)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.adaptivePrimary(colorScheme))

                Spacer()

                // Bottom ornate divider band
                bottomBand
            }
        }
    }

    private var topBand: some View {
        VStack(spacing: 16) {
            OrnateDivider(color: Color.adaptivePrimary(colorScheme))
                .padding(.horizontal, 60)
            Text(data.type == .ayah ? "بِسْمِ اللَّهِ" : "Hadith")
                .font(.custom("ScheherazadeNew-Regular", size: 28))
                .foregroundStyle(Color.adaptivePrimary(colorScheme))
            OrnateDivider(color: Color.adaptivePrimary(colorScheme))
                .padding(.horizontal, 60)
        }
        .padding(.top, 80)
        .padding(.bottom, 20)
    }

    private var bottomBand: some View {
        VStack(spacing: 16) {
            OrnateDivider(color: Color.adaptivePrimary(colorScheme))
                .padding(.horizontal, 60)
            KheirWatermark(foreground: Color.adaptiveText(colorScheme))
            OrnateDivider(color: Color.adaptivePrimary(colorScheme))
                .padding(.horizontal, 60)
        }
        .padding(.bottom, 64)
        .padding(.top, 20)
    }
}

// MARK: - Nature Share Card

/// Gradient background (teal to deep blue), white text overlay.
struct NatureShareCard: View {
    let data: ShareCardData
    let colorScheme: ColorScheme

    private let gradientColors: [Color] = [
        Color(red: 0.11, green: 0.47, blue: 0.53),   // Teal
        Color(red: 0.06, green: 0.25, blue: 0.48),   // Mid blue
        Color(red: 0.04, green: 0.10, blue: 0.28)    // Deep navy
    ]

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle star pattern overlay for texture
            StarBorderOverlay(color: .white)

            // Content
            VStack(spacing: 0) {
                Spacer()

                // Moon/star icon
                Image(systemName: data.type == .ayah ? "moon.stars.fill" : "book.closed.fill")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 32)

                // Arabic text
                if let arabic = data.arabicText, !arabic.isEmpty {
                    Text(arabic)
                        .font(.custom("ScheherazadeNew-Regular", size: 56))
                        .environment(\.layoutDirection, .rightToLeft)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 50)
                        .padding(.bottom, 30)
                }

                // Horizontal rule
                Rectangle()
                    .fill(.white.opacity(0.35))
                    .frame(height: 1)
                    .padding(.horizontal, 80)
                    .padding(.bottom, 30)

                // Content
                Text(data.content)
                    .font(.system(size: 26, weight: .light, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 60)
                    .padding(.bottom, 22)

                // Reference
                Text(data.reference)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                // Watermark
                KheirWatermark(foreground: .white)
                    .padding(.bottom, 56)
            }
            .padding(.horizontal, 40)
        }
    }
}
