import SwiftUI

// MARK: - Paper Screen Kit
//
// Small pieces shared by the feature screens (Quran, Prayer Times, Qibla, Masjid,
// Journal, Routines, Settings, Sharing). They build on `PaperKit` and keep the
// motion quiet: these screens are opened many times a day, so they get a quick
// entrance only and the icons carry the idle life.

// MARK: - Palette helpers

enum PaperInk {
    /// Kraft label paper used for section tags and clipped-on labels.
    static let kraftLabel = Color(hex: "#D9C29A")
    /// Felt green for strips and the progress ring.
    static let leaf = Color.lightPrimary
    /// Tissue-paper park green on the masjid map.
    static let parkTissue = Color(hex: "#7FAE7A")
    /// Mustard paper used for "Now" and "Nearest" tags.
    static let mustard = Color.islamicGold

    static func ink(_ scheme: ColorScheme) -> Color { .adaptiveText(scheme) }
    static func ink2(_ scheme: ColorScheme) -> Color { .adaptiveSecondaryText(scheme) }
}

// MARK: - Quick entrance

/// A light entrance for screens people open often: the piece fades in from a
/// couple of points above and 98% scale over ~0.3s, staggered ~35ms per index.
/// Runs once per appearance of the view; nothing with Reduce Motion.
struct QuickPlaceModifier: ViewModifier {
    let index: Int
    @State private var shown = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let hidden = !shown && !reduceMotion
        content
            .opacity(hidden ? 0 : 1)
            .scaleEffect(hidden ? 0.98 : 1)
            .offset(y: hidden ? -6 : 0)
            .animation(reduceMotion ? nil : .open(0.3).delay(Double(min(index, 12)) * 0.035), value: shown)
            .onAppear { shown = true }
    }
}

extension View {
    /// Quick, light entrance (≈0.3s, 35ms stagger by `index`).
    func quickPlace(_ index: Int = 0) -> some View {
        modifier(QuickPlaceModifier(index: index))
    }

    /// A small stable tilt for a paper piece so cards never sit perfectly square.
    func paperTilt(_ seed: Int, max degrees: Double = 0.7) -> some View {
        rotationEffect(.degrees((seeded(seed, salt: 5) - 0.5) * 2 * degrees))
    }
}

// MARK: - Eight-point star

/// The classic Islamic eight-point star: two squares, one turned 45°.
struct EightPointStar: Shape {
    func path(in rect: CGRect) -> Path {
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        let inner = r * 0.765
        var p = Path()
        for i in 0..<16 {
            let a = Double(i) * .pi / 8 - .pi / 2
            let rr = i.isMultiple(of: 2) ? r : inner
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }
}

/// A number on an eight-point star cut from construction paper.
struct StarBadge: View {
    let number: Int
    var color: Color = .islamicGold
    var size: CGFloat = 36
    var seed: Int = 0
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            EightPointStar()
                .fill(color)
                .overlay(PaperGrain(material: .construction, seed: seed, dark: false).clipShape(EightPointStar()))
                .paperShadow(depth: 0.5)
            Text("\(number)")
                .font(.system(size: size * (number > 99 ? 0.28 : 0.34), weight: .heavy, design: .rounded).monospacedDigit())
                .foregroundStyle(Color.lightBodyText)
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees((seeded(seed, salt: 2) - 0.5) * 8))
        .accessibilityHidden(true)
    }
}

// MARK: - Section tag

/// A torn kraft label that heads a group of cards.
struct PaperSectionTag: View {
    let title: String
    var seed: Int = 0
    var color: Color = PaperInk.kraftLabel

    var body: some View {
        PaperTag(text: title, color: color, ink: .lightBodyText, seed: seed)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Paper checkbox

/// A small square of paper. Checked, it is pressed flat (less shadow) and a
/// felt tick is dropped onto it.
struct PaperCheckbox: View {
    let isOn: Bool
    var size: CGFloat = 26
    var seed: Int = 0
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            CutShape(cornerRadius: 5, edge: .scissor, seed: seed)
                .fill(isOn ? Color.adaptivePrimary(scheme) : Color.adaptiveCardElevated(scheme))
                .overlay(PaperGrain(material: .construction, seed: seed, dark: scheme == .dark).clipShape(CutShape(cornerRadius: 5, seed: seed)))
                .overlay(CutShape(cornerRadius: 5, seed: seed).stroke(Color.adaptiveSecondaryText(scheme).opacity(isOn ? 0 : 0.35), lineWidth: 1))
                .paperShadow(depth: isOn ? 0.25 : 0.8)
            if isOn {
                TickMark()
                    .fill(Color.lightCardSurface)
                    .frame(width: size * 0.62, height: size * 0.62)
                    .shadow(color: .black.opacity(0.35), radius: 0.4, x: 0.4, y: 0.8)
                    .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity).combined(with: .offset(y: -4)), removal: .opacity))
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(isOn ? 0.96 : 1)
        .animation(.open(0.2), value: isOn)
        .accessibilityHidden(true)
    }
}

/// A chunky felt tick (as in the mockup).
struct TickMark: Shape {
    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        var p = Path()
        let pts: [(CGFloat, CGFloat)] = [(3, 13), (6, 10), (10, 14), (19, 5), (22, 8), (10, 20)]
        for (i, pt) in pts.enumerated() {
            let q = CGPoint(x: rect.minX + pt.0 * s, y: rect.minY + pt.1 * s)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }
}

// MARK: - Paper button

/// A cut-out strip button (primary action): leaf-green card with cream ink.
struct PaperButtonLabel: View {
    let title: String
    var icon: PaperIcon?
    var color: Color = .lightPrimary
    var ink: Color = .lightCardSurface
    var seed: Int = 0

    var body: some View {
        HStack(spacing: 8) {
            if let icon { PaperIconView(icon, size: 20) }
            Text(title).font(.system(size: 16, weight: .bold, design: .rounded))
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .paperPiece(color, material: .construction, depth: 1.2, radius: 14, seed: seed, padding: nil)
    }
}

// MARK: - Row divider

/// A faint pencil line between rows on a card.
struct PaperRowDivider: View {
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Rectangle()
            .fill(Color.adaptiveSecondaryText(scheme).opacity(0.18))
            .frame(height: 0.75)
            .accessibilityHidden(true)
    }
}

// MARK: - Notepaper lines

/// Ruled lines for notepaper cards, spaced `lineHeight` apart, with a margin rule.
struct NotepaperLines: View {
    var lineHeight: CGFloat = 22
    var topInset: CGFloat = 20
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Canvas { ctx, size in
            let rule = scheme == .dark ? Color(hex: "#7EB4CE").opacity(0.18) : Color(hex: "#7EB4CE").opacity(0.38)
            var y = topInset + lineHeight
            while y < size.height - 4 {
                var p = Path()
                p.move(to: CGPoint(x: 0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(p, with: .color(rule), lineWidth: 0.6)
                y += lineHeight
            }
            var margin = Path()
            margin.move(to: CGPoint(x: 30, y: 0))
            margin.addLine(to: CGPoint(x: 30, y: size.height))
            ctx.stroke(margin, with: .color(Color.paperTerracotta.opacity(scheme == .dark ? 0.22 : 0.32)), lineWidth: 0.8)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
