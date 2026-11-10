import SwiftUI

// MARK: - Animated Scroll Reveal
/// Pieces are lowered onto the table as they first appear (see `PaperPlaceModifier`).
struct ScrollRevealModifier: ViewModifier {
    let delay: Double

    func body(content: Content) -> some View {
        content.paperPlace(delay: delay, seed: Int(delay * 1000))
    }
}

// MARK: - Press Scale Interaction
struct PressScaleModifier: ViewModifier {
    let scale: CGFloat
    let opacity: Double
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? scale : 1.0)
            .opacity(isPressed ? opacity : 1.0)
            .offset(y: isPressed ? 1.5 : 0)
            .animation(.open(isPressed ? 0.12 : 0.2), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

// MARK: - Skeleton Loading
struct SkeletonModifier: ViewModifier {
    let isLoading: Bool
    @State private var shimmerPhase: CGFloat = 0

    func body(content: Content) -> some View {
        if isLoading {
            content
                .redacted(reason: .placeholder)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.radiusMD)
                        .fill(
                            LinearGradient(
                                colors: [.clear, .white.opacity(0.08), .clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .offset(x: shimmerPhase)
                        .clipped()
                )
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: false)) {
                        shimmerPhase = 300
                    }
                }
        } else {
            content
        }
    }
}

// MARK: - Featured Card Style (taped-down paper)
struct FeaturedCardModifier: ViewModifier {
    let colorScheme: ColorScheme
    var seed: Int = 7

    func body(content: Content) -> some View {
        content
            .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1.2, seed: seed)
            .overlay(alignment: .top) {
                PaperTape(seed: seed)
                    .offset(y: -9)
            }
    }
}

/// A strip of translucent washi tape holding a piece to the table.
struct PaperTape: View {
    var seed: Int = 0

    var body: some View {
        Rectangle()
            .fill(Color.islamicGold.opacity(0.55))
            .frame(width: 64, height: 18)
            .mask(CutShape(cornerRadius: 1, edge: .torn, seed: seed + 40))
            .overlay(PaperGrain(material: .tissue, seed: seed).mask(Rectangle().frame(width: 64, height: 18)))
            .rotationEffect(.degrees((seeded(seed, salt: 3) - 0.5) * 8))
            .shadow(color: .black.opacity(0.08), radius: 0.5, y: 0.5)
            .accessibilityHidden(true)
    }
}

// MARK: - Over-sky card (paper lifted off the backdrop)
struct GlassmorphismCardModifier: ViewModifier {
    let colorScheme: ColorScheme
    var seed: Int = 3

    func body(content: Content) -> some View {
        content
            .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1.8, seed: seed)
    }
}

// MARK: - Overline Text Style
struct OverlineStyle: ViewModifier {
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .font(.system(size: 11, weight: .regular))
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.adaptiveGold(colorScheme).opacity(0.7))
    }
}

extension View {
    func scrollReveal(delay: Double = 0) -> some View {
        modifier(ScrollRevealModifier(delay: delay))
    }

    func arabicFont(size: CGFloat) -> some View {
        self.font(.custom("ScheherazadeNew-Regular", size: size))
            .environment(\.layoutDirection, .rightToLeft)
    }

    func cardStyle(_ colorScheme: ColorScheme, seed: Int = 0) -> some View {
        paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 1, seed: seed)
    }

    func featuredCardStyle(_ colorScheme: ColorScheme, seed: Int = 7) -> some View {
        modifier(FeaturedCardModifier(colorScheme: colorScheme, seed: seed))
    }

    func glassmorphismCard(_ colorScheme: ColorScheme, seed: Int = 3) -> some View {
        modifier(GlassmorphismCardModifier(colorScheme: colorScheme, seed: seed))
    }

    func pressScale(_ scale: CGFloat = DesignTokens.pressScaleCard, opacity: Double = 1.0) -> some View {
        modifier(PressScaleModifier(scale: scale, opacity: opacity))
    }

    func skeleton(isLoading: Bool) -> some View {
        modifier(SkeletonModifier(isLoading: isLoading))
    }

    func overlineStyle(_ colorScheme: ColorScheme) -> some View {
        modifier(OverlineStyle(colorScheme: colorScheme))
    }
}

// MARK: - Geometric Pattern Background
struct IslamicPatternBackground: View {
    let colorScheme: ColorScheme

    var body: some View {
        Canvas { context, size in
            let patternSize: CGFloat = 40
            let color = Color.adaptivePrimary(colorScheme).opacity(0.05)
            for row in 0..<Int(size.height / patternSize) + 1 {
                for col in 0..<Int(size.width / patternSize) + 1 {
                    let x = CGFloat(col) * patternSize
                    let y = CGFloat(row) * patternSize
                    let center = CGPoint(x: x + patternSize / 2, y: y + patternSize / 2)
                    let radius = patternSize * 0.3

                    // Eight-pointed star pattern
                    var path = Path()
                    for i in 0..<8 {
                        let angle = Double(i) * .pi / 4
                        let outerPoint = CGPoint(
                            x: center.x + radius * cos(angle),
                            y: center.y + radius * sin(angle)
                        )
                        let innerAngle = angle + .pi / 8
                        let innerPoint = CGPoint(
                            x: center.x + radius * 0.4 * cos(innerAngle),
                            y: center.y + radius * 0.4 * sin(innerAngle)
                        )
                        if i == 0 {
                            path.move(to: outerPoint)
                        } else {
                            path.addLine(to: outerPoint)
                        }
                        path.addLine(to: innerPoint)
                    }
                    path.closeSubpath()
                    context.fill(path, with: .color(color))
                }
            }
        }
        .drawingGroup()
    }
}
