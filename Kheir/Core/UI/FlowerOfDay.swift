import SwiftUI

// MARK: - Flower of the Day
//
// One paper flower per calendar day. The date alone picks the species and its
// paper colours, so everyone sees the same flower on the same day and the
// garden on the sky's hills is a record of past days.

enum FlowerSpecies: Int, CaseIterable, Sendable {
    case jasmine, daisy, sakura, tulip, rose, sunflower, lotus, poppy, lavender, hibiscus

    var name: String {
        switch self {
        case .jasmine: "Jasmine"
        case .daisy: "Daisy"
        case .sakura: "Sakura"
        case .tulip: "Tulip"
        case .rose: "Rose"
        case .sunflower: "Sunflower"
        case .lotus: "Lotus"
        case .poppy: "Poppy"
        case .lavender: "Lavender"
        case .hibiscus: "Hibiscus"
        }
    }

    /// Paper colour pairs (main, lighter layer) this species can be cut from.
    var palettes: [(Color, Color)] {
        switch self {
        case .jasmine: [(Color(hex: "#FBF5E8"), Color(hex: "#F3E8D2")), (Color(hex: "#FFFFFF"), Color(hex: "#F6EBC8"))]
        case .daisy: [(Color(hex: "#FBF5E8"), Color(hex: "#F6EBC8")), (Color(hex: "#E6A08C"), Color(hex: "#F4C2B5"))]
        case .sakura: [(Color(hex: "#F4B6C2"), Color(hex: "#F9D3DA")), (Color(hex: "#E6A08C"), Color(hex: "#F4C2B5"))]
        case .tulip: [(Color(hex: "#D2694B"), Color(hex: "#E98C6E")), (Color(hex: "#E3B65A"), Color(hex: "#F2CF78")), (Color(hex: "#B5476B"), Color(hex: "#D46A8C"))]
        case .rose: [(Color(hex: "#C0392B"), Color(hex: "#D9574A")), (Color(hex: "#E6A08C"), Color(hex: "#F2BFAF")), (Color(hex: "#E3B65A"), Color(hex: "#F2CF78"))]
        case .sunflower: [(Color(hex: "#E3B65A"), Color(hex: "#F2CF78"))]
        case .lotus: [(Color(hex: "#E79AB0"), Color(hex: "#F6C6D3")), (Color(hex: "#FBF5E8"), Color(hex: "#F4D6DE"))]
        case .poppy: [(Color(hex: "#D2402B"), Color(hex: "#E5644C")), (Color(hex: "#E58A3A"), Color(hex: "#F0A860"))]
        case .lavender: [(Color(hex: "#8E7CC3"), Color(hex: "#B3A4DD"))]
        case .hibiscus: [(Color(hex: "#D2694B"), Color(hex: "#E98C6E")), (Color(hex: "#C2185B"), Color(hex: "#E04F80")), (Color(hex: "#E3B65A"), Color(hex: "#F2CF78"))]
        }
    }
}

struct DailyFlower: Sendable {
    let species: FlowerSpecies
    let petal: Color
    let petalLight: Color
    /// Resting tilt in degrees, so no two flowers stand the same way.
    let tilt: Double

    /// A stable day number for `date` in the user's calendar.
    static func dayNumber(_ date: Date, calendar: Calendar = .current) -> Int {
        calendar.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    static func forDay(_ day: Int) -> DailyFlower {
        let species = FlowerSpecies.allCases[((day % 10) + 10) % 10]
        let v = seeded(day, salt: 5)
        let pair = species.palettes[min(species.palettes.count - 1, Int(v * Double(species.palettes.count)))]
        return DailyFlower(species: species, petal: pair.0, petalLight: pair.1, tilt: (v - 0.5) * 14)
    }

    static func forDate(_ date: Date) -> DailyFlower { forDay(dayNumber(date)) }
}

// MARK: - Drawing

enum FlowerArt {
    static let green = Color(hex: "#3E7350")
    static let greenLight = Color(hex: "#5F9A6E")
    static let gold = Color(hex: "#E3B65A")

    /// Draws `flower` with the base of its stem at the context's origin, `size` pt wide.
    /// Art is authored in a 40 × 46 box whose stem base sits at (0, 22).
    static func draw(_ flower: DailyFlower, in context: GraphicsContext, size: CGFloat) {
        var ctx = context
        let s = size / 40
        ctx.scaleBy(x: s, y: s)
        ctx.translateBy(x: 0, y: -22)
        if flower.species != .lavender { drawStem(&ctx) }
        drawHead(flower, &ctx)
    }

    private static func drawStem(_ ctx: inout GraphicsContext) {
        var stem = Path()
        stem.move(to: CGPoint(x: 0, y: 6))
        stem.addQuadCurve(to: CGPoint(x: 0, y: 22), control: CGPoint(x: 2, y: 14))
        ctx.stroke(stem, with: .color(green), lineWidth: 2.2)
        var leaf = Path()
        leaf.move(to: CGPoint(x: 1, y: 15))
        leaf.addCurve(to: CGPoint(x: 12, y: 14), control1: CGPoint(x: 6, y: 10), control2: CGPoint(x: 11, y: 12))
        leaf.addCurve(to: CGPoint(x: 1, y: 15), control1: CGPoint(x: 8, y: 16), control2: CGPoint(x: 4, y: 17))
        ctx.fill(leaf, with: .color(greenLight))
    }

    private static func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
    }

    /// `n` petals of length `len` radiating from the centre.
    private static func ring(_ ctx: inout GraphicsContext, n: Int, len: CGFloat, width: CGFloat, color: Color, offset: Double = 0) {
        for k in 0..<n {
            var c = ctx
            c.rotate(by: .degrees(offset + Double(k) * 360 / Double(n)))
            c.fill(ellipse(0, -len / 2, width, len / 2), with: .color(color))
        }
    }

    private static func petalShape(_ ctx: inout GraphicsContext, count: Int, color: (Int) -> Color, offset: Double = 0, _ build: (inout Path) -> Void) {
        for k in 0..<count {
            var c = ctx
            c.rotate(by: .degrees(offset + Double(k) * 360 / Double(count)))
            var p = Path()
            build(&p)
            c.fill(p, with: .color(color(k)))
        }
    }

    private static func drawHead(_ f: DailyFlower, _ ctx: inout GraphicsContext) {
        let c1 = f.petal, c2 = f.petalLight
        switch f.species {
        case .jasmine:
            petalShape(&ctx, count: 5, color: { $0.isMultiple(of: 2) ? c1 : c2 }, offset: 15) { p in
                p.move(to: .zero)
                p.addCurve(to: CGPoint(x: 0, y: -16), control1: CGPoint(x: -6, y: -5), control2: CGPoint(x: -6, y: -14))
                p.addCurve(to: .zero, control1: CGPoint(x: 5, y: -15), control2: CGPoint(x: 7, y: -8))
            }
            ctx.fill(ellipse(0, 0, 2.6, 2.6), with: .color(gold))
        case .daisy:
            ring(&ctx, n: 14, len: 15, width: 2.4, color: c1)
            ring(&ctx, n: 14, len: 12, width: 2, color: c2, offset: 12.8)
            ctx.fill(ellipse(0, 0, 4.6, 4.6), with: .color(gold))
            ctx.fill(ellipse(-1, -1, 2.4, 2.4), with: .color(Color(hex: "#F2CF78")))
        case .sakura:
            petalShape(&ctx, count: 5, color: { $0.isMultiple(of: 2) ? c1 : c2 }) { p in
                p.move(to: .zero)
                p.addCurve(to: CGPoint(x: -2.5, y: -16), control1: CGPoint(x: -7, y: -4), control2: CGPoint(x: -8, y: -13))
                p.addLine(to: CGPoint(x: 0, y: -13.5))
                p.addLine(to: CGPoint(x: 2.5, y: -16))
                p.addCurve(to: .zero, control1: CGPoint(x: 8, y: -13), control2: CGPoint(x: 7, y: -4))
            }
            ctx.fill(ellipse(0, 0, 2.4, 2.4), with: .color(Color(hex: "#B5476B")))
        case .tulip:
            var cup = Path()
            cup.move(to: CGPoint(x: -9, y: -4))
            cup.addCurve(to: CGPoint(x: 0, y: -14), control1: CGPoint(x: -10, y: -14), control2: CGPoint(x: -5, y: -18))
            cup.addCurve(to: CGPoint(x: 9, y: -4), control1: CGPoint(x: 5, y: -18), control2: CGPoint(x: 10, y: -14))
            cup.addCurve(to: CGPoint(x: -9, y: -4), control1: CGPoint(x: 8, y: 4), control2: CGPoint(x: -8, y: 4))
            ctx.fill(cup, with: .color(c1))
            var front = Path()
            front.move(to: CGPoint(x: -4, y: -2))
            front.addCurve(to: CGPoint(x: 0, y: -16), control1: CGPoint(x: -6, y: -12), control2: CGPoint(x: -1, y: -17))
            front.addCurve(to: CGPoint(x: 2, y: 2), control1: CGPoint(x: 3, y: -13), control2: CGPoint(x: 4, y: -6))
            front.closeSubpath()
            ctx.fill(front, with: .color(c2))
        case .rose:
            ctx.fill(ellipse(0, 0, 14, 14), with: .color(c1))
            ctx.fill(ellipse(1, -1, 10.5, 10.5), with: .color(c2))
            ctx.fill(ellipse(-1, 0, 7, 7), with: .color(c1))
            var swirl = Path()
            swirl.addArc(center: CGPoint(x: -0.5, y: 0.5), radius: 3.5, startAngle: .degrees(200), endAngle: .degrees(520), clockwise: false)
            ctx.stroke(swirl, with: .color(c2), lineWidth: 2)
        case .sunflower:
            ring(&ctx, n: 16, len: 17, width: 2.6, color: c1)
            ring(&ctx, n: 16, len: 13, width: 2.2, color: c2, offset: 11)
            ctx.fill(ellipse(0, 0, 7.5, 7.5), with: .color(Color(hex: "#6B4423")))
            for k in 0..<9 {
                let a = Double(k) * 2.4, r = CGFloat(k) * 0.6
                ctx.fill(ellipse(CGFloat(cos(a)) * r, CGFloat(sin(a)) * r, 0.8, 0.8), with: .color(Color(hex: "#3A2412")))
            }
        case .lotus:
            for (k, a) in [-60.0, -30, 0, 30, 60].enumerated() {
                var c = ctx
                c.translateBy(x: 0, y: 6)
                c.rotate(by: .degrees(a))
                var p = Path()
                p.move(to: .zero)
                p.addCurve(to: CGPoint(x: 0, y: -22), control1: CGPoint(x: -6, y: -8), control2: CGPoint(x: -4, y: -18))
                p.addCurve(to: .zero, control1: CGPoint(x: 4, y: -18), control2: CGPoint(x: 6, y: -8))
                c.fill(p, with: .color(k.isMultiple(of: 2) ? c1 : c2))
            }
            var pad = Path()
            pad.move(to: CGPoint(x: -12, y: 7))
            pad.addQuadCurve(to: CGPoint(x: 12, y: 7), control: CGPoint(x: 0, y: 12))
            pad.addQuadCurve(to: CGPoint(x: -12, y: 7), control: CGPoint(x: 0, y: 9))
            ctx.fill(pad, with: .color(greenLight))
        case .poppy:
            for (k, a) in [20.0, 110, 200, 290].enumerated() {
                var c = ctx
                c.rotate(by: .degrees(a))
                c.fill(ellipse(0, -7, 8.5, 8.5), with: .color(k.isMultiple(of: 2) ? c1 : c2))
            }
            ctx.fill(ellipse(0, 0, 4, 4), with: .color(Color(hex: "#2B2118")))
        case .lavender:
            var stem = Path()
            stem.move(to: CGPoint(x: 0, y: 22))
            stem.addLine(to: CGPoint(x: 0, y: -14))
            ctx.stroke(stem, with: .color(green), lineWidth: 2)
            for k in 0..<7 {
                let side: CGFloat = k.isMultiple(of: 2) ? -2.6 : 2.6
                var c = ctx
                c.translateBy(x: side, y: -14 + CGFloat(k) * 3.6)
                c.rotate(by: .degrees(side < 0 ? -20 : 20))
                c.fill(ellipse(0, 0, 2.6, 3.4), with: .color(k.isMultiple(of: 2) ? c1 : c2))
            }
        case .hibiscus:
            petalShape(&ctx, count: 5, color: { $0.isMultiple(of: 2) ? c1 : c2 }) { p in
                p.move(to: .zero)
                p.addCurve(to: CGPoint(x: -3, y: -17), control1: CGPoint(x: -9, y: -3), control2: CGPoint(x: -11, y: -15))
                p.addCurve(to: .zero, control1: CGPoint(x: 2, y: -18), control2: CGPoint(x: 9, y: -14))
            }
            var stamen = Path()
            stamen.move(to: .zero)
            stamen.addLine(to: CGPoint(x: 7, y: -10))
            ctx.stroke(stamen, with: .color(gold), lineWidth: 1.6)
            ctx.fill(ellipse(7.5, -10.5, 1.6, 1.6), with: .color(gold))
        }
    }
}

// MARK: - View

/// Today's paper flower, swaying gently from the base of its stem.
struct DailyFlowerView: View {
    var date: Date = .now
    var size: CGFloat = 36
    /// Paused while scrolled out of view.
    @State private var isOnScreen = true

    var body: some View {
        let flower = DailyFlower.forDate(date)
        LoopClock(period: 7_600, paused: !isOnScreen, fps: 20) { t in
            Canvas { ctx, canvasSize in
                var c = ctx
                c.translateBy(x: canvasSize.width / 2, y: canvasSize.height * 0.95)
                c.rotate(by: .degrees(flower.tilt + 4 * wave(t, period: 7_600)))
                c.addFilter(.shadow(color: Color(red: 0.12, green: 0.06, blue: 0.02).opacity(0.3), radius: 1.2, x: 0.6, y: 1.2))
                FlowerArt.draw(flower, in: c, size: size)
            }
        }
        .frame(width: size * 1.2, height: size * 1.3)
        .onScrollVisibilityChange(threshold: 0.01) { isOnScreen = $0 }
        .accessibilityLabel("Today's flower: \(flower.species.name)")
    }
}

#if DEBUG
#Preview("A week of flowers") {
    HStack {
        ForEach(0..<7, id: \.self) { k in
            DailyFlowerView(date: Calendar.current.date(byAdding: .day, value: k, to: .now) ?? .now, size: 32)
        }
    }
    .padding()
    .background(Color.lightBackground)
}
#endif
