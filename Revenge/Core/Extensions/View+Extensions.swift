import SwiftUI

// MARK: - Animated Scroll Reveal
struct ScrollRevealModifier: ViewModifier {
    let delay: Double
    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .opacity(hasAppeared ? 1 : 0)
            .offset(y: hasAppeared || reduceMotion ? 0 : 20)
            .animation(reduceMotion ? .none : .easeOut(duration: 0.45).delay(delay), value: hasAppeared)
            .onAppear {
                if !hasAppeared {
                    hasAppeared = true
                }
            }
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
            .animation(.spring(response: DesignTokens.springResponse, dampingFraction: DesignTokens.springDamping), value: isPressed)
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

// MARK: - Featured Card Style (Gold Border)
struct FeaturedCardModifier: ViewModifier {
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .padding(DesignTokens.cardPadding)
            .background(
                Color.adaptiveCardSurface(colorScheme)
                    .opacity(colorScheme == .dark ? 0.8 : 1.0)
            )
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cardRadius)
                    .stroke(Color.adaptiveGoldBorder(colorScheme), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.06), radius: DesignTokens.cardShadowRadius, y: DesignTokens.cardShadowY)
    }
}

// MARK: - Glassmorphism Card (Over Sky)
struct GlassmorphismCardModifier: ViewModifier {
    let colorScheme: ColorScheme

    func body(content: Content) -> some View {
        content
            .padding(DesignTokens.cardPadding)
            .background(.ultraThinMaterial)
            .background(Color.adaptiveCardSurface(colorScheme).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cardRadius)
                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
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

    func cardStyle(_ colorScheme: ColorScheme) -> some View {
        self.padding(DesignTokens.cardPadding)
            .background(Color.adaptiveCardSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cardRadius)
                    .stroke(Color.adaptiveBorder(colorScheme), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.2 : 0.06), radius: DesignTokens.cardShadowRadius, y: DesignTokens.cardShadowY)
    }

    func featuredCardStyle(_ colorScheme: ColorScheme) -> some View {
        modifier(FeaturedCardModifier(colorScheme: colorScheme))
    }

    func glassmorphismCard(_ colorScheme: ColorScheme) -> some View {
        modifier(GlassmorphismCardModifier(colorScheme: colorScheme))
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
