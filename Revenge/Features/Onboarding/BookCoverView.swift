import SwiftUI

// MARK: - BookCoverView

/// The closed leather book cover shown at the start of onboarding.
/// Tapping it triggers the `onOpen` callback with haptic feedback.
struct BookCoverView: View {
    let onOpen: () -> Void

    // MARK: - Private constants

    private let leatherTop    = Color(red: 0.102, green: 0.188, blue: 0.157)
    private let leatherMid    = Color(red: 0.051, green: 0.122, blue: 0.102)
    private let leatherBottom = Color(red: 0.039, green: 0.094, blue: 0.082)
    private let gold          = Color(red: 0.831, green: 0.659, blue: 0.278)
    private let spineWidth: CGFloat = 18
    private let pageStripColors: [Color] = [
        Color(red: 0.941, green: 0.910, blue: 0.855),
        Color(red: 0.910, green: 0.878, blue: 0.820),
        Color(red: 0.878, green: 0.847, blue: 0.784)
    ]
    private let pageStripWidths: [CGFloat] = [8, 6, 4]

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Page edge strips — right side, behind cover
                pageEdgeStack(height: geo.size.height)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                // Main cover surface
                coverSurface
                    .overlay(spineSurface, alignment: .leading)
                    .overlay(borderFrame)
                    .overlay(centerContent)

                // Tap affordance
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipShape(BookCoverShape())
        .shadow(color: .black.opacity(0.5), radius: 20, x: 6, y: 6)
        .onTapGesture {
            HapticManager.shared.lightTap()
            onOpen()
        }
        .accessibilityLabel("Open Kheir — tap to begin")
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Sub-views

    /// Layered cream-coloured strips that simulate stacked pages on the right edge.
    private func pageEdgeStack(height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(pageStripWidths.enumerated()), id: \.offset) { index, width in
                Rectangle()
                    .fill(pageStripColors[index])
                    .frame(width: width)
                    .frame(height: height - CGFloat(index) * 2)
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 12,
                topTrailingRadius: 12
            )
        )
    }

    /// Dark leather gradient background of the cover.
    private var coverSurface: some View {
        LinearGradient(
            colors: [leatherTop, leatherMid, leatherBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Left-edge spine with darker gradient, gold thread lines, and raised ridges.
    private var spineSurface: some View {
        ZStack(alignment: .leading) {
            // Spine base gradient — darker than cover
            LinearGradient(
                colors: [
                    Color(red: 0.027, green: 0.059, blue: 0.051),
                    Color(red: 0.051, green: 0.094, blue: 0.078),
                    Color(red: 0.027, green: 0.059, blue: 0.051)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: spineWidth)

            // Gold thread lines
            VStack {
                Spacer()
                Rectangle()
                    .fill(gold.opacity(0.10))
                    .frame(width: spineWidth, height: 2)
                Spacer()
                Rectangle()
                    .fill(gold.opacity(0.10))
                    .frame(width: spineWidth, height: 2)
                Spacer()
            }
            .frame(width: spineWidth)

            // Spine ridges — top cluster
            VStack(spacing: 4) {
                spineRidge
                spineRidge
            }
            .frame(width: spineWidth)
            .padding(.top, 24)
            .frame(maxHeight: .infinity, alignment: .top)

            // Spine ridges — bottom cluster
            VStack(spacing: 4) {
                spineRidge
                spineRidge
            }
            .frame(width: spineWidth)
            .padding(.bottom, 24)
            .frame(maxHeight: .infinity, alignment: .bottom)

            // Right edge highlight for depth
            LinearGradient(
                colors: [.clear, .white.opacity(0.06), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: spineWidth)
        }
        .frame(width: spineWidth)
    }

    /// A single horizontal ridge bar on the spine.
    private var spineRidge: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.039, green: 0.082, blue: 0.063),
                        Color(red: 0.086, green: 0.141, blue: 0.118),
                        Color(red: 0.039, green: 0.082, blue: 0.063)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: spineWidth - 4, height: 5)
            .shadow(color: .black.opacity(0.4), radius: 1, x: 0, y: 1)
    }

    /// Double inset gold border frame (outer 1pt at 20% + inner 0.5pt at 10%).
    private var borderFrame: some View {
        GeometryReader { geo in
            ZStack {
                // Outer border
                RoundedRectangle(cornerRadius: 8)
                    .stroke(gold.opacity(0.20), lineWidth: 1)
                    .padding(.leading, spineWidth + 12)
                    .padding(.trailing, 20)
                    .padding(.vertical, 20)

                // Inner border
                RoundedRectangle(cornerRadius: 6)
                    .stroke(gold.opacity(0.10), lineWidth: 0.5)
                    .padding(.leading, spineWidth + 16)
                    .padding(.trailing, 24)
                    .padding(.vertical, 24)
            }
        }
    }

    /// Center content: ornaments, crescent, title, divider, subtitle.
    private var centerContent: some View {
        VStack(spacing: 0) {
            // Top ornament
            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(gold.opacity(0.55))
                .padding(.bottom, 16)

            // Crescent icon in gold circle border
            ZStack {
                Circle()
                    .stroke(gold.opacity(0.75), lineWidth: 1)
                    .frame(width: 56, height: 56)

                Image(systemName: "moon.stars")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(gold)
            }
            .padding(.bottom, 18)

            // App name
            Text("KHEIR")
                .font(.system(size: 24, weight: .light, design: .serif))
                .tracking(6)
                .foregroundStyle(gold)
                .padding(.bottom, 14)

            // Gold divider
            Rectangle()
                .fill(gold.opacity(0.45))
                .frame(width: 64, height: 0.5)
                .padding(.bottom, 14)

            // Subtitle overline
            Text("SPIRITUAL COMPANION")
                .font(.system(size: 10, weight: .regular, design: .default))
                .tracking(2.5)
                .foregroundStyle(gold.opacity(0.65))
                .padding(.bottom, 20)

            // Bottom ornament
            Image(systemName: "sparkle")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(gold.opacity(0.55))
        }
        .padding(.leading, spineWidth)
    }
}

// MARK: - BookCoverShape

/// Custom shape: 4px radius on the left (spine side), 12px on the right.
private struct BookCoverShape: Shape {
    func path(in rect: CGRect) -> Path {
        let spineRadius: CGFloat = 4
        let coverRadius: CGFloat = 12

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + spineRadius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - coverRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + coverRadius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - coverRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - coverRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + spineRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - spineRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + spineRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + spineRadius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.039, green: 0.059, blue: 0.118)
            .ignoresSafeArea()

        BookCoverView(onOpen: { })
            .frame(width: 300, height: 420)
    }
}
