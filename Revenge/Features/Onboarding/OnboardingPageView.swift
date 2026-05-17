import SwiftUI

// MARK: - OnboardingPageView

/// A single onboarding page styled as a physical book page.
///
/// Design:
/// - Warm cream background (#F0E8DA).
/// - Fold shadow on the left edge (book-spine side).
/// - Thin page-edge strips on the right (depth simulation).
/// - Chapter marker header with gold divider lines.
/// - Generic content slot.
/// - Faint page number in the bottom-right corner.
struct OnboardingPageView<Content: View>: View {
    // MARK: Parameters

    let chapterNumber: Int
    let pageNumber: Int
    @ViewBuilder let content: () -> Content

    // MARK: Private constants

    private let creamBackground = Color(red: 0.941, green: 0.910, blue: 0.855)
    private let gold             = Color(red: 0.831, green: 0.659, blue: 0.278)
    private let inkColor         = Color(red: 0.102, green: 0.165, blue: 0.133)

    private let foldShadowWidth:  CGFloat = 24
    private let pageEdgeWidths:   [CGFloat] = [6, 4]
    private let pageEdgeColors: [Color] = [
        Color(red: 0.910, green: 0.878, blue: 0.820),
        Color(red: 0.878, green: 0.847, blue: 0.784)
    ]

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .trailing) {
                // Right-side page-edge strips (behind main surface)
                pageEdgeStack(height: geo.size.height)

                // Main page surface
                pageSurface
                    .overlay(foldShadowOverlay, alignment: .leading)
                    .overlay(chapterHeader, alignment: .top)
                    .overlay(pageNumberLabel, alignment: .bottomTrailing)
                    .overlay(contentArea)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .clipShape(PageShape())
    }

    // MARK: - Sub-views

    /// Cream paper background.
    private var pageSurface: some View {
        creamBackground
    }

    /// Gradient shadow simulating the page curl / spine fold.
    private var foldShadowOverlay: some View {
        LinearGradient(
            stops: [
                .init(color: .black.opacity(0.08), location: 0),
                .init(color: .black.opacity(0.03), location: 0.4),
                .init(color: .clear, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: foldShadowWidth)
    }

    /// Stacked thin strips on the right edge simulating page depth.
    private func pageEdgeStack(height: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(pageEdgeWidths.enumerated()), id: \.offset) { index, width in
                Rectangle()
                    .fill(pageEdgeColors[index])
                    .frame(width: width)
                    .frame(height: height - CGFloat(index) * 2)
            }
        }
        .frame(maxHeight: .infinity, alignment: .center)
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 12,
                topTrailingRadius: 12
            )
        )
    }

    /// Chapter marker: line + "CHAPTER X" label + line.
    private var chapterHeader: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Rectangle()
                    .fill(gold.opacity(0.55))
                    .frame(height: 0.5)

                Text("CHAPTER \(chapterNumberWord)")
                    .font(.system(size: 9, weight: .medium, design: .default))
                    .tracking(2.5)
                    .foregroundStyle(gold.opacity(0.75))
                    .fixedSize()

                Rectangle()
                    .fill(gold.opacity(0.55))
                    .frame(height: 0.5)
            }
            .padding(.horizontal, foldShadowWidth + 16)
            .padding(.top, 28)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    /// Generic content area inset from both shadow edge and page edges.
    private var contentArea: some View {
        VStack {
            // Spacer for chapter header height
            Spacer().frame(height: 60)

            content()
                .padding(.horizontal, foldShadowWidth + 12)
                .padding(.bottom, 36)

            Spacer()
        }
    }

    /// Faint page number bottom-right.
    private var pageNumberLabel: some View {
        Text("\(pageNumber)")
            .font(.system(size: 9, weight: .light, design: .serif))
            .foregroundStyle(inkColor.opacity(0.25))
            .padding(.bottom, 14)
            .padding(.trailing, 22)
    }

    // MARK: - Helpers

    private var chapterNumberWord: String {
        switch chapterNumber {
        case 1: "ONE"
        case 2: "TWO"
        case 3: "THREE"
        case 4: "FOUR"
        case 5: "FIVE"
        default: "\(chapterNumber)"
        }
    }
}

// MARK: - PageShape

/// Right-angle on the left edge (spine-facing), 12px radius on the right.
private struct PageShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 12
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color(red: 0.039, green: 0.059, blue: 0.118)
            .ignoresSafeArea()

        OnboardingPageView(chapterNumber: 1, pageNumber: 1) {
            VStack(spacing: 16) {
                Image(systemName: "location.circle")
                    .font(.system(size: 44))
                    .foregroundStyle(Color(red: 0.133, green: 0.341, blue: 0.235))

                Text("Your Location")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color(red: 0.102, green: 0.165, blue: 0.133))

                Text("For accurate prayer times and Qibla direction.")
                    .font(.system(size: 15))
                    .foregroundStyle(Color(red: 0.102, green: 0.165, blue: 0.133).opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(width: 300, height: 420)
    }
}
