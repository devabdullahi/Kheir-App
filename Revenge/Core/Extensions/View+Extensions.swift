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

extension View {
    func scrollReveal(delay: Double = 0) -> some View {
        modifier(ScrollRevealModifier(delay: delay))
    }

    func arabicFont(size: CGFloat) -> some View {
        self.font(.custom("ScheherazadeNew-Regular", size: size))
            .environment(\.layoutDirection, .rightToLeft)
    }

    func cardStyle(_ colorScheme: ColorScheme) -> some View {
        self.padding(16)
            .background(Color.adaptiveCardSurface(colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.3 : 0.08), radius: 8, y: 4)
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
