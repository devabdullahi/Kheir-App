import SwiftUI

// MARK: - Paper Kit
//
// The app's surfaces are cut paper laid on a table under a warm lamp. Three rules:
// 1. Everything is a paper piece: a flat colour, a material grain and a cut edge.
// 2. Depth is shadow. A piece sitting higher off the table casts a longer, softer
//    shadow down and to the right (the lamp is top-left). Never fake 3D otherwise.
// 3. Edges are cut by hand: scissor cuts wobble gently, torn edges are ragged.
//    Each piece has its own `seed`, so no two cuts look the same.

// MARK: - Materials

enum PaperMaterial {
    /// Smooth cardstock: cards and sheets.
    case card
    /// Construction paper: visible fibres and flecks.
    case construction
    /// Brown kraft: the table and warm accents.
    case kraft
    /// Felt: soft, dense fuzz. Used for small accents.
    case felt
    /// Thin tissue: lighter shadow, slight see-through.
    case tissue

    var grainOpacity: Double {
        switch self {
        case .card: return 0.05
        case .construction: return 0.09
        case .kraft: return 0.14
        case .felt: return 0.16
        case .tissue: return 0.04
        }
    }

    var fibreCount: Int {
        switch self {
        case .card: return 70
        case .construction: return 140
        case .kraft: return 220
        case .felt: return 320
        case .tissue: return 40
        }
    }

    var shadowScale: Double { self == .tissue ? 0.55 : 1 }
}

enum PaperEdge {
    /// Scissor cut: a slow, gentle wobble (characters, props, cards).
    case scissor
    /// Hand-torn: ragged, high-frequency (landscapes, labels, banners).
    case torn
}

// MARK: - Cut Shape

/// A rounded rectangle cut by hand. The outline is sampled every few points and
/// pushed in and out along its normal by stable seeded noise.
struct CutShape: Shape {
    var cornerRadius: CGFloat = 18
    var edge: PaperEdge = .scissor
    var seed: Int = 0

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        let points = Self.perimeter(of: rect, radius: r, spacing: edge == .torn ? 3 : 6)
        guard points.count > 2 else { return Path(roundedRect: rect, cornerRadius: r) }

        var path = Path()
        for (i, sample) in points.enumerated() {
            let d = PaperNoise.edgeOffset(i: i, s: sample.s, seed: seed, edge: edge)
            let p = CGPoint(x: sample.p.x + sample.n.dx * d, y: sample.p.y + sample.n.dy * d)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    struct Sample { let p: CGPoint; let n: CGVector; let s: CGFloat }

    /// Points around a rounded rect, clockwise from the top-left straight, each with
    /// its outward normal and arc length `s`.
    static func perimeter(of rect: CGRect, radius r: CGFloat, spacing: CGFloat) -> [Sample] {
        var out: [Sample] = []
        var s: CGFloat = 0
        func line(_ a: CGPoint, _ b: CGPoint, _ n: CGVector) {
            let len = hypot(b.x - a.x, b.y - a.y)
            let steps = max(1, Int(len / spacing))
            for k in 0..<steps {
                let f = CGFloat(k) / CGFloat(steps)
                out.append(Sample(p: CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f), n: n, s: s + len * f))
            }
            s += len
        }
        func arc(_ c: CGPoint, from a0: CGFloat) {
            guard r > 0 else { return }
            let len = r * .pi / 2
            let steps = max(2, Int(len / spacing))
            for k in 0..<steps {
                let a = a0 + (.pi / 2) * CGFloat(k) / CGFloat(steps)
                let n = CGVector(dx: cos(a), dy: sin(a))
                out.append(Sample(p: CGPoint(x: c.x + n.dx * r, y: c.y + n.dy * r), n: n, s: s + len * CGFloat(k) / CGFloat(steps)))
            }
            s += len
        }
        let (x0, y0, x1, y1) = (rect.minX, rect.minY, rect.maxX, rect.maxY)
        line(CGPoint(x: x0 + r, y: y0), CGPoint(x: x1 - r, y: y0), CGVector(dx: 0, dy: -1))
        arc(CGPoint(x: x1 - r, y: y0 + r), from: -.pi / 2)
        line(CGPoint(x: x1, y: y0 + r), CGPoint(x: x1, y: y1 - r), CGVector(dx: 1, dy: 0))
        arc(CGPoint(x: x1 - r, y: y1 - r), from: 0)
        line(CGPoint(x: x1 - r, y: y1), CGPoint(x: x0 + r, y: y1), CGVector(dx: 0, dy: 1))
        arc(CGPoint(x: x0 + r, y: y1 - r), from: .pi / 2)
        line(CGPoint(x: x0, y: y1 - r), CGPoint(x: x0, y: y0 + r), CGVector(dx: -1, dy: 0))
        arc(CGPoint(x: x0 + r, y: y0 + r), from: .pi)
        return out
    }
}

// MARK: - Noise

enum PaperNoise {
    /// How far (pt) the cut wanders from the ideal outline at arc length `s`.
    static func edgeOffset(i: Int, s: CGFloat, seed: Int, edge: PaperEdge) -> CGFloat {
        let salt = Double(seed) * 0.37
        let x = Double(s)
        // Slow wobble: the hand guiding the scissors.
        let phaseA: Double = seeded(seed, salt: 1) * 6.28
        let phaseB: Double = seeded(seed, salt: 2) * 6.28
        let slow: Double = 0.55 * sin(x / 37 + phaseA) + 0.35 * sin(x / 13 + phaseB)
        switch edge {
        case .scissor:
            return CGFloat(slow * 0.9)
        case .torn:
            // Ragged fibres on top of the wobble, biased inward so a tear never bulges.
            let fine: Double = (seeded(i, salt: salt + 3) - 0.5) * 2.2
            let coarse: Double = (seeded(i / 3, salt: salt + 4) - 0.5) * 1.6
            return CGFloat(slow * 1.4 + fine + coarse - 0.8)
        }
    }

    /// A torn horizontal edge across `width`, around `y`, for landscape strips.
    static func tornLine(width: CGFloat, y: CGFloat, amplitude: CGFloat, seed: Int, spacing: CGFloat = 4) -> [CGPoint] {
        let steps = Int(width / spacing) + 2
        return (0...steps).map { k in
            let x = CGFloat(k) * spacing - spacing
            let xd = Double(x)
            let phaseA: Double = seeded(seed, salt: 5) * 6.28
            let phaseB: Double = seeded(seed, salt: 6) * 6.28
            let roll: Double = sin(xd / 61 + phaseA) * 0.6 + sin(xd / 23 + phaseB) * 0.4
            let rag: Double = (seeded(k, salt: Double(seed) + 7) - 0.5) * 2.4
            return CGPoint(x: x, y: y + CGFloat(roll) * amplitude + CGFloat(rag))
        }
    }
}

// MARK: - Grain

/// Fibres and flecks of a sheet of paper. Static: drawn once per size.
struct PaperGrain: View {
    var material: PaperMaterial = .card
    var seed: Int = 0
    var dark = false

    var body: some View {
        Canvas { ctx, size in
            let count = Int(Double(material.fibreCount) * Double(size.width * size.height) / 90_000) + 12
            let ink = dark ? Color.white : Color(red: 0.25, green: 0.17, blue: 0.08)
            for i in 0..<count {
                let x = seeded(i, salt: Double(seed)) * size.width
                let y = seeded(i, salt: Double(seed) + 0.5) * size.height
                let kind = seeded(i, salt: Double(seed) + 0.9)
                if kind < 0.7 {
                    // a short curled fibre
                    let a = seeded(i, salt: Double(seed) + 1.3) * .pi * 2
                    let len = 2 + seeded(i, salt: Double(seed) + 1.7) * 5
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: y))
                    p.addQuadCurve(
                        to: CGPoint(x: x + cos(a) * len, y: y + sin(a) * len),
                        control: CGPoint(x: x + cos(a + 0.8) * len * 0.6, y: y + sin(a + 0.8) * len * 0.6)
                    )
                    ctx.stroke(p, with: .color(ink.opacity(0.5 + kind * 0.5)), lineWidth: 0.5)
                } else {
                    // a fleck
                    let r = 0.4 + seeded(i, salt: Double(seed) + 2.1) * 0.8
                    ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(ink))
                }
            }
        }
        .opacity(material.grainOpacity * (dark ? 1.2 : 1))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Paper Piece

/// Turns any view into a cut-paper piece lying on the table.
struct PaperPieceModifier: ViewModifier {
    let color: Color
    var material: PaperMaterial = .card
    var depth: CGFloat = 1
    var edge: PaperEdge = .scissor
    var radius: CGFloat = DesignTokens.cardRadius
    var seed: Int = 0
    var padding: CGFloat? = DesignTokens.cardPadding
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let shape = CutShape(cornerRadius: radius, edge: edge, seed: seed)
        content
            .padding(padding ?? 0)
            .background {
                ZStack {
                    shape.fill(color)
                    PaperGrain(material: material, seed: seed, dark: scheme == .dark)
                        .clipShape(shape)
                    // The top-left rim catches the lamp; the bottom-right turns away from it.
                    shape.stroke(
                        LinearGradient(
                            colors: [.white.opacity(scheme == .dark ? 0.16 : 0.55), .clear, .black.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
                }
                .paperShadow(depth: depth * material.shadowScale)
            }
    }
}

extension View {
    /// A cut-paper piece. `depth` is its height off the table: 0.3–0.8 background,
    /// ~1 cards, 1.5–3 for things lifted or floating.
    func paperPiece(
        _ color: Color,
        material: PaperMaterial = .card,
        depth: CGFloat = 1,
        edge: PaperEdge = .scissor,
        radius: CGFloat = DesignTokens.cardRadius,
        seed: Int = 0,
        padding: CGFloat? = DesignTokens.cardPadding
    ) -> some View {
        modifier(PaperPieceModifier(color: color, material: material, depth: depth, edge: edge, radius: radius, seed: seed, padding: padding))
    }

    /// Two stacked shadows: a tight contact shadow where the paper meets the table,
    /// and a soft cast shadow thrown down-right by the lamp. Both grow with depth.
    func paperShadow(depth: CGFloat = 1) -> some View {
        self
            .shadow(color: Color(red: 0.12, green: 0.07, blue: 0.02).opacity(0.22), radius: 0.6 + 0.4 * depth, x: 0.4 * depth, y: 0.8 * depth)
            .shadow(color: Color(red: 0.18, green: 0.10, blue: 0.03).opacity(0.18), radius: 3 + 3 * depth, x: 1.5 * depth, y: 3 * depth)
    }
}

// MARK: - Table

/// The surface every screen sits on: a sheet of construction paper under a warm
/// lamp, brighter top-left and falling off into the corners.
struct PaperTableBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            Color.adaptiveBackground(scheme)
            PaperGrain(material: .construction, seed: 91, dark: scheme == .dark)
            // Lamp pool
            RadialGradient(
                colors: [
                    Color(red: 1, green: 0.86, blue: 0.62).opacity(scheme == .dark ? 0.10 : 0.28),
                    .clear
                ],
                center: UnitPoint(x: 0.2, y: 0.08),
                startRadius: 10,
                endRadius: 620
            )
            // Vignette into the corners of the photo
            RadialGradient(
                colors: [.clear, .black.opacity(scheme == .dark ? 0.35 : 0.12)],
                center: UnitPoint(x: 0.45, y: 0.4),
                startRadius: 260,
                endRadius: 760
            )
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    func paperBackground() -> some View {
        background { PaperTableBackground() }
    }
}

// MARK: - Brass Brad

/// A split-pin fastener, like the joints of a paper puppet.
struct BrassBrad: View {
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#F6DE93"), Color(hex: "#C79A3A"), Color(hex: "#7E5A1C")],
                    center: UnitPoint(x: 0.32, y: 0.3),
                    startRadius: 0,
                    endRadius: size * 0.7
                )
            )
            .overlay(Circle().stroke(Color(hex: "#5E4214").opacity(0.5), lineWidth: 0.5))
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.35), radius: 0.8, x: 0.6, y: 1)
            .accessibilityHidden(true)
    }
}

// MARK: - Paper Tag

/// A small torn label, like a hand-cut price tag: used for overlines and chips.
struct PaperTag: View {
    let text: String
    var color: Color
    var ink: Color
    var seed: Int = 0

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .paperPiece(color, material: .construction, depth: 0.6, edge: .torn, radius: 3, seed: seed, padding: nil)
            .rotationEffect(.degrees((seeded(seed, salt: 9) - 0.5) * 3))
    }
}

// MARK: - Placed on the table

/// Entrance for a paper piece: it is lowered onto the table from slightly above
/// (bigger, longer shadow) and settles in a few stop-motion steps.
struct PaperPlaceModifier: ViewModifier {
    let delay: Double
    let seed: Int
    @State private var placed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let lifted = !placed && !reduceMotion
        content
            .scaleEffect(lifted ? 1.035 : 1)
            .rotationEffect(.degrees(lifted ? (seeded(seed, salt: 4) - 0.5) * 4 : 0))
            .offset(x: lifted ? -3 : 0, y: lifted ? -10 : 0)
            .opacity(lifted ? 0 : 1)
            .animation(reduceMotion ? nil : .open(0.42).delay(delay), value: placed)
            .onAppear { placed = true }
    }
}

extension View {
    /// Lowers this piece onto the table when it first appears.
    func paperPlace(delay: Double = 0, seed: Int = 0) -> some View {
        modifier(PaperPlaceModifier(delay: delay, seed: seed))
    }
}

/// Press feedback for a paper button: the piece is pushed flat onto the table.
struct PaperPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .offset(y: configuration.isPressed ? 1.5 : 0)
            .animation(.open(configuration.isPressed ? 0.12 : 0.2), value: configuration.isPressed)
    }
}
