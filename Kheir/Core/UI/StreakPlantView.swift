import SwiftUI

// MARK: - Streak Plant
//
// A paper clay pot whose plant grows with the streak, day by day, into a date
// palm (the app's logo). Stages: day 1 a seed in the soil, day 3 a sprout,
// day 7 two fronds, day 14 a young palm with a trunk, day 30 full fronds,
// day 40 the first dates, day 100 a mature palm heavy with dates. Inside each
// stage everything is interpolated, so the plant grows a little every day.
// A missed day only wilts it (`isWilted`): the fronds droop, it never dies.
//
// Drawn in a 100×100 design space with the same paper brush as `PaperIconView`.

struct StreakPlantView: View {
    let days: Int
    var size: CGFloat = 120
    var animated: Bool = true
    var isWilted: Bool = false

    init(days: Int, size: CGFloat = 120, animated: Bool = true, isWilted: Bool = false) {
        self.days = days
        self.size = size
        self.animated = animated
        self.isWilted = isWilted
    }

    /// The sway loop: 5200 (trunk), 3600 and 2340 (fronds), 2600 (dates) all fit 46.8 s.
    private static let period: Double = 46_800

    /// Paused while scrolled out of view, and rests after a short sway.
    @State private var isOnScreen = true
    @State private var resting = false

    var body: some View {
        Group {
            if animated {
                LoopClock(period: Self.period, paused: !isOnScreen || resting, fps: 15) { t in art(t) }
            } else {
                art(0)
            }
        }
        .frame(width: size, height: size)
        .paperShadow(depth: 0.6)
        .onScrollVisibilityChange(threshold: 0.01) { isOnScreen = $0 }
        .task {
            try? await Task.sleep(for: .seconds(12))
            resting = true
        }
        .accessibilityElement()
        .accessibilityLabel(Self.accessibilityText(days: days, wilted: isWilted))
    }

    private func art(_ t: Double) -> some View {
        let growth = PalmGrowth(days: days)
        let wilted = isWilted
        let size = size
        let pad = size * 0.06
        return Canvas { ctx, _ in
            let brush = PIconBrush(ctx: ctx, unit: size / 100, origin: CGPoint(x: pad, y: pad), shadowUnit: max(1, size / 70))
            PalmArt.draw(growth, t: t, wilted: wilted, brush: brush)
        }
        .frame(width: size + pad * 2, height: size + pad * 2)
        .frame(width: size, height: size)
    }

    static func accessibilityText(days: Int, wilted: Bool) -> String {
        let stage = PalmGrowth(days: days).stageName
        let base = days <= 0 ? "No streak yet, \(stage)" : "\(days)-day streak, \(stage)"
        return wilted ? base + ", a little wilted" : base
    }
}

// MARK: - Growth

/// Everything about the plant that depends on the streak length.
struct PalmGrowth: Equatable {
    let days: Double

    init(days: Int) { self.days = Double(max(0, days)) }

    /// Piecewise-linear through (day, value) keys; flat outside them.
    private func ramp(_ keys: [(Double, Double)]) -> Double {
        guard let first = keys.first, let last = keys.last else { return 0 }
        if days <= first.0 { return first.1 }
        if days >= last.0 { return last.1 }
        for i in 1..<keys.count where days <= keys[i].0 {
            let (d0, v0) = keys[i - 1], (d1, v1) = keys[i]
            return v0 + (v1 - v0) * (days - d0) / (d1 - d0)
        }
        return last.1
    }

    enum Stage { case seed, sprout, palm }

    var stage: Stage {
        if days < 3 { return .seed }
        if days < 7 { return .sprout }
        return .palm
    }

    var stageName: String {
        switch days {
        case ..<3: "seed in the soil"
        case ..<7: "sprout"
        case ..<14: "seedling with two fronds"
        case ..<30: "young palm"
        case ..<40: "palm with full fronds"
        case ..<100: "palm with dates"
        default: "mature palm with dates"
        }
    }

    /// Seed stage: 0 at day 1 (or 0), 1 just before day 3. A green tip peeks out on day 2.
    var seedProgress: Double { ramp([(1, 0), (3, 1)]) }

    /// Sprout stage: 0 at day 3, 1 at day 7.
    var sproutProgress: Double { ramp([(3, 0), (7, 1)]) }

    /// Trunk segments (fractional: the top one grows in).
    var trunk: Double { ramp([(13, 0), (14, 1.2), (30, 3.2), (40, 4), (100, 7)]) }

    /// Overall frond length factor; keeps growing slowly for a year after day 100.
    var frondScale: Double { ramp([(7, 0.62), (14, 0.66), (30, 0.78), (40, 0.8), (100, 1), (365, 1.06)]) }

    /// How unfurled frond `i` is (0 hidden … 1 grown) — each appears on its own day.
    func frond(_ i: Int) -> Double {
        let appear = PalmArt.fronds[i].appears
        return min(1, max(0, (days - appear + 0.6) / 4))
    }

    /// Size of date `i` (0 hidden … 1 full). The first set at day 40, more until ~80.
    func date(_ i: Int) -> Double {
        let appear = 40 + Double(i) * 7
        return min(1, max(0, (days - appear + 2) / 4))
    }

    /// Dates ripen from gold toward a deep amber by day 100.
    var ripeness: Double { ramp([(40, 0), (100, 1)]) }
}

// MARK: - The art

private enum PalmArt {
    typealias B = PIconBrush

    struct Frond {
        let angle: Double     // degrees: 0 points right, -90 up
        let length: CGFloat
        let color: UInt32
        let appears: Double   // the streak day it starts to unfurl
    }

    /// Back to front, left to right (from the loading-screen palm).
    static let fronds: [Frond] = [
        Frond(angle: -168, length: 31, color: 0x2F5E3F, appears: 26),
        Frond(angle: -138, length: 34, color: 0x3E7350, appears: 18),
        Frond(angle: -108, length: 29, color: 0x5F9A6E, appears: 4),
        Frond(angle: -80, length: 28, color: 0x3E7350, appears: 14),
        Frond(angle: -52, length: 30, color: 0x5F9A6E, appears: 4),
        Frond(angle: -24, length: 33, color: 0x3E7350, appears: 21),
        Frond(angle: 4, length: 31, color: 0x2F5E3F, appears: 26),
    ]

    /// Date positions under the crown (relative to the hub).
    static let dates: [(CGFloat, CGFloat)] = [(-1.8, 5.4), (1.8, 5.4), (-5.2, 3.6), (5.2, 3.6), (0, 8.6), (-3.6, 8), (3.6, 8)]

    static let soilTop: CGFloat = 75
    static let base = CGPoint(x: 50, y: 77)

    static func draw(_ g: PalmGrowth, t: Double, wilted: Bool, brush b: B) {
        // Soil inside the pot's mouth.
        b.flat(B.rect(32.5, 71.5, 35, 6, radius: 2.5), B.hex(0x6B4423))

        switch g.stage {
        case .seed: seed(g, t: t, wilted: wilted, b)
        case .sprout: sprout(g, t: t, wilted: wilted, b)
        case .palm: palm(g, t: t, wilted: wilted, b)
        }

        // The clay pot: body, then the rim glued on top (it hides the trunk's foot).
        b.flat(PIconSVG.path("M32 79h36l-4.6 18.5H36.6z"), B.hex(0xD2694B))
        b.lift(PIconSVG.path("M36.6 97.5h26.8l-.4 1.5H37z"), B.hex(0xB85A3E), opacity: 0.6)
        b.lift(B.rect(29, 73.5, 42, 7.5, radius: 1.2), B.hex(0xB85A3E), depth: 1.3)
        b.lift(B.rect(31, 75.2, 38, 1.2, radius: 0.6), B.hex(0xE98C6E), opacity: 0.55, depth: 0.3)
    }

    // MARK: Seed (days 0–2)

    private static func seed(_ g: PalmGrowth, t: Double, wilted: Bool, _ b: B) {
        let p = g.seedProgress
        let breathe = 1 + 0.03 * wave(t, period: 5_200)
        let s = CGFloat((1 + 0.15 * p) * breathe)
        let c = CGPoint(x: 50, y: 71.6)
        let seedT = B.rotate(-14, about: c).concatenating(B.scale(s, s, about: CGPoint(x: 50, y: 75)))
        b.lift(Path(ellipseIn: CGRect(x: c.x - 4.4, y: c.y - 2.9, width: 8.8, height: 5.8)), B.hex(0xB88B5E), seedT)
        b.flat(PIconSVG.path("M47.2 71.9c1.6-.9 4-1.1 5.8-.5"), B.hex(0x8A6440), seedT)
        // Day 2: a green tip peeks out of the seed.
        if p >= 0.45 {
            let tip = CGFloat(min(1, (p - 0.45) / 0.55))
            let sway = B.rotate(3 * wave(t, period: 3_600) + (wilted ? 18 : 0), about: CGPoint(x: 51, y: 69.4))
            var stem = Path()
            stem.move(to: CGPoint(x: 51, y: 69.4))
            stem.addQuadCurve(to: CGPoint(x: 51.8 + 0.8 * tip, y: 69.4 - 5 * tip), control: CGPoint(x: 50.4, y: 67.6))
            b.strip(stem, width: 1.2, B.hex(0x5F9A6E), sway, cap: .round)
        }
    }

    // MARK: Sprout (days 3–6)

    private static func sprout(_ g: PalmGrowth, t: Double, wilted: Bool, _ b: B) {
        let p = CGFloat(g.sproutProgress)
        let h = 9 + 8 * p
        let droop: Double = wilted ? 1 : 0
        let lean = 3 * wave(t, period: 5_200) + 6 * droop
        let stemT = B.rotate(lean, about: base)
        let top = CGPoint(x: base.x + 0.6, y: base.y - h)
        var stem = Path()
        stem.move(to: base)
        stem.addQuadCurve(to: top, control: CGPoint(x: base.x - 1.2, y: base.y - h * 0.55))
        b.strip(stem, width: 1.6 + 0.4 * p, B.hex(0x3E7350), stemT, cap: .round)

        // Two leaves (the sprout icon's leaves), sized with the day, swaying out of phase.
        let k = 1.3 + 0.6 * p
        let leafL = PIconSVG.path("M11.8 10.5 C8 10.6 6 8.4 6.2 6.6 C9 6.4 11.3 8 11.8 10.5Z")
        let leafR = PIconSVG.path("M12.1 8.2 C15.4 8.6 17.8 6.6 17.8 4.6 C14.8 4.4 12.6 5.8 12.1 8.2Z")
        let lAnchor = CGPoint(x: base.x - 0.3, y: base.y - h * 0.62)
        let rAnchor = CGPoint(x: top.x, y: top.y + 0.4)
        let lT = CGAffineTransform(translationX: -11.8, y: -10.5)
            .concatenating(CGAffineTransform(scaleX: k, y: k))
            .concatenating(B.rotate(5 * wave(t, period: 3_600, phase: 0.1) - 22 * droop, about: .zero))
            .concatenating(B.move(lAnchor.x, lAnchor.y))
            .concatenating(stemT)
        let rT = CGAffineTransform(translationX: -12.1, y: -8.2)
            .concatenating(CGAffineTransform(scaleX: k, y: k))
            .concatenating(B.rotate(5 * wave(t, period: 2_340, phase: 0.45) + 24 * droop, about: .zero))
            .concatenating(B.move(rAnchor.x, rAnchor.y))
            .concatenating(stemT)
        b.lift(leafL, B.hex(0x5F9A6E), lT)
        b.lift(leafR, B.hex(0x7FAE7A), rT)
    }

    // MARK: Palm (day 7 on)

    private static func palm(_ g: PalmGrowth, t: Double, wilted: Bool, _ b: B) {
        // The whole palm sways around its foot; the fronds lag behind it (follow-through).
        let sway = 0.8 * wave(t, period: 5_200) + (wilted ? 2.5 : 0)
        let whole = B.rotate(sway, about: base)

        // Trunk: kraft chevrons stacked bottom-up, leaning a little more toward the top.
        let segH: CGFloat = 6.2
        let maxSegs: CGFloat = 7
        let trunk = CGFloat(g.trunk)
        var hub = CGPoint(x: base.x, y: base.y - 2)
        var y = base.y + 2
        var i = 0
        while CGFloat(i) < trunk {
            let f = min(1, trunk - CGFloat(i))
            let lean = pow(CGFloat(i) / maxSegs, 2) * 5
            let leanTop = pow(CGFloat(i + 1) / maxSegs, 2) * 5
            let w = 4.8 - CGFloat(i) * 0.32
            let h = segH * f
            var seg = Path()
            seg.move(to: CGPoint(x: base.x + lean - w, y: y))
            seg.addLine(to: CGPoint(x: base.x + lean + w, y: y))
            seg.addLine(to: CGPoint(x: base.x + leanTop + w - 0.6, y: y - h))
            seg.addLine(to: CGPoint(x: base.x + leanTop, y: y - h - 1.6 * f))
            seg.addLine(to: CGPoint(x: base.x + leanTop - w + 0.6, y: y - h))
            seg.closeSubpath()
            b.lift(seg, B.hex(i % 2 == 0 ? 0xB88B5E : 0xA87B4F), whole, depth: 0.8)
            y -= h * 0.86
            hub = CGPoint(x: base.x + leanTop, y: y - h * 0.14 - 0.4)
            i += 1
        }

        // Fronds.
        let scale = CGFloat(g.frondScale)
        for (k, fr) in fronds.enumerated() {
            let grown = g.frond(k)
            guard grown > 0 else { continue }
            let spread = abs(fr.angle + 90) / 90
            let follow = -0.5 * sway
            let idle = (2.6 * wave(t, period: 3_600, phase: Double(k) * 0.13)
                        + 1.2 * wave(t, period: 2_340, phase: 0.4 + Double(k) * 0.17)) * (spread + 0.4)
            // Unfurling: a new frond starts folded up and opens to its angle.
            let open = -90 + (fr.angle + 90) * easeOut.value(at: grown)
            let side: Double = fr.angle < -90 ? -1 : 1
            let droop = wilted ? side * (10 + 8 * spread) : 0
            let len = fr.length * scale * CGFloat(0.55 + 0.45 * grown)
            let shape = leaf(length: len, width: len * 0.28, seed: k + 1, droop: wilted ? 1.45 : 1)
            let flip: CGFloat = side < 0 ? -1 : 1
            let tf = CGAffineTransform(scaleX: 1, y: flip)
                .concatenating(B.rotate(open + follow + idle + droop, about: .zero))
                .concatenating(B.move(hub.x, hub.y))
                .concatenating(whole)
            let color = wilted ? B.mix(fr.color, 0x8C8A4E, 0.35) : B.hex(fr.color)
            b.lift(shape, color, tf, depth: 1.1 + CGFloat(k) * 0.05)
        }

        // A brass brad pins the fronds once there is a trunk.
        if trunk > 0.3 {
            let r: CGFloat = 1.5 + 0.5 * min(1, trunk / 3)
            b.lift(B.circle(hub.x, hub.y, r), B.hex(0xC79A3A), whole, depth: 0.6)
            b.flat(B.circle(hub.x - r * 0.3, hub.y - r * 0.3, r * 0.4), B.hex(0xF6DE93), whole)
        }

        // Dates hang under the crown, bobbing gently; they ripen from gold to amber.
        let ripe = g.ripeness
        let anyDates = (0..<dates.count).contains { g.date($0) > 0 }
        if anyDates {
            var stalk = Path()
            stalk.move(to: CGPoint(x: hub.x, y: hub.y + 1))
            stalk.addQuadCurve(to: CGPoint(x: hub.x, y: hub.y + 6), control: CGPoint(x: hub.x + 1, y: hub.y + 3))
            b.strip(stalk, width: 0.9, B.hex(0x8A6440), whole, lifted: false, cap: .round)
        }
        let dateScale = 0.8 + 0.2 * CGFloat(ripe)
        for (k, d) in dates.enumerated() {
            let s = g.date(k)
            guard s > 0 else { continue }
            let bob = 0.5 * wave(t, period: 2_600, phase: Double(k) * 0.21)
            let rx = 2.3 * dateScale * CGFloat(s), ry = 3.2 * dateScale * CGFloat(s)
            let c = CGPoint(x: hub.x + d.0 * dateScale, y: hub.y + d.1 * dateScale + CGFloat(bob) + (wilted ? 0.4 : 0))
            let gold: UInt32 = k % 2 == 0 ? 0xD4A843 : 0xC8A951
            let deep: UInt32 = k % 2 == 0 ? 0xB0652A : 0x9C5527
            b.lift(Path(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: rx * 2, height: ry * 2)),
                   B.mix(gold, deep, ripe), whole, depth: 0.9)
        }
    }

    /// A palm frond: curved midrib drooping toward the tip, a serrated cut edge, one outline.
    /// Lies along +x from the origin.
    static func leaf(length len: CGFloat, width wid: CGFloat, seed: Int, droop: CGFloat) -> Path {
        let n = 11
        var up: [CGPoint] = []
        var dn: [CGPoint] = []
        for i in 0...n {
            let f = CGFloat(i) / CGFloat(n)
            let x = f * len
            let y = sin(f * .pi * 0.9) * -wid * 0.15 + f * f * wid * 0.9 * droop
            let w = wid * sin(.pi * min(1, f * 1.1)) * (0.6 + 0.4 * (1 - f))
            let odd = i % 2 == 1
            up.append(CGPoint(x: x, y: y - w * 0.35))
            dn.append(CGPoint(x: x + (odd && i < n - 1 ? len * 0.033 : 0),
                              y: y + w * (odd ? 0.55 : 1) * (0.9 + CGFloat(seeded(i, salt: Double(seed))) * 0.2)))
        }
        var p = Path()
        p.move(to: .zero)
        for q in up { p.addLine(to: q) }
        for q in dn.reversed() { p.addLine(to: q) }
        p.closeSubpath()
        return p
    }
}

// MARK: - Previews

#Preview("Streak plant stages") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 12)], spacing: 16) {
            ForEach([1, 2, 3, 5, 7, 10, 14, 21, 30, 40, 60, 100], id: \.self) { d in
                VStack(spacing: 4) {
                    StreakPlantView(days: d, size: 110)
                    Text("Day \(d)").font(.caption).foregroundStyle(.secondary)
                }
            }
            VStack(spacing: 4) {
                StreakPlantView(days: 40, size: 110, isWilted: true)
                Text("Day 40, wilted").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }
    .background(PIconBrush.hex(0xEADBC0))
}

#Preview("Streak plant milestones") {
    HStack(spacing: 0) {
        ForEach([1, 3, 7, 14, 30, 40, 100], id: \.self) { d in
            StreakPlantView(days: d, size: 54, animated: false)
        }
    }
    .padding()
    .background(PIconBrush.hex(0xEADBC0))
}
