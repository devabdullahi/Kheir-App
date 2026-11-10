import SwiftUI

// MARK: - Paper loading scene
//
// Main action (first launch only): a date palm is assembled from paper on a green
// construction-paper table. Dunes slide up from below, a crescent moon drops in on
// its thread and swings to rest with two small stars, trunk chevrons are stacked
// bottom-up, fronds unfold, a brass brad pins them, dates drop and squash, the
// letters of "Kheir" are placed one by one and the Arabic tag slides in.
//
// Idle (always): fronds sway with follow-through, the moon and stars rock on their
// threads, and three paper dates hop as the loading indicator.
//
// Rules: pieces enter already moving from beyond the screen edge and never teleport;
// opacity is only used to appear. Reduce Motion shows the final frame, still.

enum LoadingBeats {
    // Windows in ms: [start, end] or [start, stagger, duration] per piece.
    static let dunes = (0.0, 420.0)
    static let moon = 150.0
    static let trunk = (480.0, 140.0, 260.0)
    static let fronds = (900.0, 55.0, 380.0)
    static let brad = (1280.0, 1380.0)
    static let dates = (1300.0, 50.0, 260.0)
    static let letters = (1600.0, 70.0, 300.0)
    static let tag = (2000.0, 2380.0)
    static let load = 2300.0
    /// The build clock runs a little past the last beat so the moon's swing has settled.
    static let end = 4000.0
    /// Idle loop: every idle period divides it, so the loop never jumps.
    static let idleLoop = 46_800.0
}

struct PaperLoadingScene: View {
    /// `false` on returning launches: the scene starts assembled.
    let playsBuild: Bool
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if playsBuild {
                OneShotClock(duration: LoadingBeats.end, play: true) { build in
                    idle(build: build, loadFrom: LoadingBeats.load)
                }
            } else {
                idle(build: LoadingBeats.end, loadFrom: 0)
            }
        }
        .overlay {
            PaperGrain(material: .construction, seed: 23)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private func idle(build: Double, loadFrom: Double) -> some View {
        LoopClock(period: LoadingBeats.idleLoop, paused: scenePhase != .active) { t in
            Canvas { ctx, size in
                LoadingSceneDrawing(size: size, build: build, idle: t, loadFrom: loadFrom).draw(ctx)
            }
        }
    }
}

// MARK: - Drawing

private struct LoadingSceneDrawing {
    let size: CGSize
    /// Build clock (ms), held at `LoadingBeats.end` once assembled.
    let build: Double
    /// Idle clock (ms), looping.
    let idle: Double
    /// Idle time at which the hopping dates fade in.
    let loadFrom: Double

    private var W: CGFloat { size.width }
    private var H: CGFloat { size.height }
    private var cx: CGFloat { W / 2 }
    private var baseY: CGFloat { H * 0.64 }

    // Palette
    static let table = Color(hex: "#1E5C2A")
    static let tableTissue = Color(hex: "#2A6E37")
    static let cream = Color(hex: "#FBF5E8")
    static let moon = Color(hex: "#F6EBC8")
    static let mustard = Color(hex: "#E3B65A")
    static let terracotta = Color(hex: "#D2694B")
    static let duneBack = Color(hex: "#C9A46A")
    static let duneFront = Color(hex: "#B88B5E")
    static let trunkA = Color(hex: "#B88B5E")
    static let trunkB = Color(hex: "#A87B4F")
    static let dateA = Color(hex: "#C8A951")
    static let dateB = Color(hex: "#D4A843")

    /// Idle layers fade in after the build, so nothing is ever all stopped at once.
    private var live: Double { seg(build, LoadingBeats.fronds.0 + 200, LoadingBeats.fronds.0 + 1400, easeOut: false) }

    func draw(_ ctx: GraphicsContext) {
        drawTable(ctx)
        drawHanging(ctx)
        let dOff = (1 - seg(build, LoadingBeats.dunes.0, LoadingBeats.dunes.1)) * H * 0.45
        piece(ctx, 0.7, dune(top: baseY + 6, amp: 10, seed: 400, offset: dOff), Self.duneBack)
        drawPalm(ctx)
        piece(ctx, 1, dune(top: baseY + 22, amp: 7, seed: 401, offset: dOff), Self.duneFront)
        drawTitle(ctx)
        drawTag(ctx)
        drawHoppingDates(ctx)
    }

    // MARK: Table

    private func drawTable(_ ctx: GraphicsContext) {
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Self.table))
        var c = ctx
        c.opacity = 0.35
        piece(c, 0.3, cutCircle(W * 0.15, H * 0.24, 150, seed: 7), Self.tableTissue)
        piece(c, 0.3, cutCircle(W * 0.9, H * 0.82, 120, seed: 8), Self.tableTissue)
    }

    // MARK: Moon and stars on threads

    /// Something hanging on a thread from above the screen: it drops in already
    /// moving, swings to rest (damped), then keeps rocking gently.
    private func hang(_ ctx: GraphicsContext, x: CGFloat, length: CGFloat, start: Double, duration: Double,
                      amp: Double, period: Double, phase: Double, draw: (GraphicsContext) -> Void) {
        guard build >= start else { return }
        let p = seg(build, start, start + duration)
        let drop = (1 - p) * -(length + 90)
        let since = max(0, build - start - duration * 0.6)
        let settle = amp * 2.2 * exp(-since / 700) * sin(since / 170)
        let rock = amp * wave(idle, period: period, phase: phase)
        var c = ctx
        c.translateBy(x: x, y: -4)
        c.rotate(by: .degrees(settle + rock))
        var thread = Path()
        thread.move(to: .zero)
        thread.addLine(to: CGPoint(x: 0, y: length + drop - 2))
        c.stroke(thread, with: .color(Self.cream.opacity(0.55)), lineWidth: 0.8)
        c.translateBy(x: 0, y: length + drop)
        draw(c)
    }

    private func twinkle(period: Double, phase: Double) -> CGFloat {
        let p = loop(idle, period: period, phase: phase)
        return 1 - 0.15 * (p < 0.12 ? bell(p / 0.12) : 0)
    }

    private func drawHanging(_ ctx: GraphicsContext) {
        hang(ctx, x: cx + 46, length: H * 0.17, start: LoadingBeats.moon, duration: 620, amp: 2.2, period: 5200, phase: 0) { c in
            let r: CGFloat = 34, ox = r * 0.34, oy = r * 0.94
            var glow = c
            glow.opacity = 0.18
            glow.fill(cutCircle(ox + 4, oy, r * 1.9, seed: 11), with: .color(Self.cream))
            glow.opacity = 0.16
            glow.fill(cutCircle(ox + 4, oy, r * 1.4, seed: 12), with: .color(Self.moon))
            // The thread is tied straight above the crescent's centre of mass, so it hangs balanced.
            piece(c, 2.4, crescent(cx: ox, cy: oy, r: r, bx: r * 0.5, by: -r * 0.2, br: r * 0.92), Self.moon)
            brass(c, center: CGPoint(x: 0, y: 3), radius: 2.8)
        }
        hang(ctx, x: cx - 92, length: H * 0.12, start: LoadingBeats.moon + 180, duration: 480, amp: 3.5, period: 3900, phase: 0.3) { c in
            piece(c, 1.8, star(x: 0, y: 8, r: 9 * twinkle(period: 3600, phase: 0.2), rot: 8), Self.mustard)
        }
        hang(ctx, x: cx + 128, length: H * 0.07, start: LoadingBeats.moon + 300, duration: 480, amp: 4, period: 3120, phase: 0.6) { c in
            piece(c, 1.6, star(x: 0, y: 6, r: 6.5 * twinkle(period: 4680, phase: 0.7), rot: -10), Self.cream)
        }
    }

    // MARK: Palm

    private func drawPalm(_ ctx: GraphicsContext) {
        let sway = 0.8 * wave(idle, period: 5200) * live
        var c = ctx
        c.translateBy(x: cx - 18, y: baseY + 14)
        c.rotate(by: .degrees(sway))
        c.scaleBy(x: 1.25, y: 1.25)

        // Trunk: seven kraft chevrons, each lowered onto the one below.
        let segs = 7, segH: CGFloat = 19
        for i in 0..<segs {
            let (a, st, du) = LoadingBeats.trunk
            let t0 = a + Double(i) * st
            let p = seg(build, t0, t0 + du)
            guard p > 0 else { continue }
            let fi = CGFloat(i)
            let lean = pow(fi / CGFloat(segs), 2) * 16
            let y = -fi * segH * 0.86
            let w = 16 - fi * 1.1
            let drop = CGFloat(1 - p) * -14
            var path = Path()
            path.move(to: CGPoint(x: lean - w, y: y + drop))
            path.addLine(to: CGPoint(x: lean + w, y: y + drop))
            path.addLine(to: CGPoint(x: lean + w - 2, y: y - segH + drop))
            path.addLine(to: CGPoint(x: lean, y: y - segH - 5 + drop))
            path.addLine(to: CGPoint(x: lean - w + 2, y: y - segH + drop))
            path.closeSubpath()
            var pc = c
            pc.opacity = min(1, p * 3)
            piece(pc, 0.8 + (1 - p) * 2, path, i % 2 == 1 ? Self.trunkB : Self.trunkA)
        }

        // Fronds: unfold from folded-up to their angle, then sway; they lag the trunk.
        let hub = CGPoint(x: pow(CGFloat(segs - 1), 2) / pow(CGFloat(segs), 2) * 16,
                          y: -CGFloat(segs - 1) * segH * 0.86 - segH)
        let fronds: [(Double, CGFloat, Color)] = [
            (-168, 92, Color(hex: "#2F5E3F")), (-138, 100, Color(hex: "#3E7350")), (-108, 84, Color(hex: "#5F9A6E")),
            (-80, 78, Color(hex: "#3E7350")), (-52, 86, Color(hex: "#5F9A6E")), (-24, 98, Color(hex: "#3E7350")),
            (4, 90, Color(hex: "#2F5E3F"))
        ]
        for (i, frond) in fronds.enumerated() {
            let (a, st, du) = LoadingBeats.fronds
            let t0 = a + Double(i) * st
            let p = seg(build, t0, t0 + du)
            guard p > 0 else { continue }
            let (ang, len, col) = frond
            let settle = -90 + (ang + 90) * p
            let follow = -0.5 * sway
            let reach = abs(ang + 90) / 90 + 0.4   // outer fronds move more than the upright ones
            let breeze = (2.6 * wave(idle, period: 3600, phase: Double(i) * 0.13)
                          + 1.2 * wave(idle, period: 2340, phase: 0.4 + Double(i) * 0.17)) * live * reach
            var fc = c
            fc.translateBy(x: hub.x, y: hub.y)
            fc.rotate(by: .degrees(settle + follow + breeze))
            let s = 0.8 + 0.2 * p
            fc.scaleBy(x: s, y: ang < -90 ? -s : s)
            piece(fc, 1.4 + CGFloat(i) * 0.05, frondPath(length: len, width: 26, seed: i + 1), col)
        }

        // A brass brad pins the fronds, pressed down from slightly above.
        if build > LoadingBeats.brad.0 {
            let bp = seg(build, LoadingBeats.brad.0, LoadingBeats.brad.1)
            var bc = c
            bc.translateBy(x: hub.x, y: hub.y)
            let s = 1.4 - 0.4 * bp
            bc.scaleBy(x: s, y: s)
            var shadowed = bc
            shadowed.addFilter(.shadow(color: Color(red: 0.08, green: 0.04, blue: 0.02).opacity(0.3), radius: 1.5 + 1.5 * (1 - bp), x: 0.6, y: 1.2 + 2 * (1 - bp)))
            brass(shadowed, center: .zero, radius: 5.5)
        }

        // Dates: drop with gravity, squash on contact (volume kept), then bob.
        let dates: [(CGFloat, CGFloat, Color)] = [(-15, 10, Self.dateA), (-5, 15, Self.dateB), (5, 15, Self.dateA), (15, 10, Self.dateB)]
        for (i, date) in dates.enumerated() {
            let (a, st, du) = LoadingBeats.dates
            let t0 = a + Double(i) * st, t1 = t0 + du
            guard build >= t0 else { continue }
            let f = min(1, (build - t0) / du)
            let fall = -46 * (1 - f * f)
            let since = build - t1
            let sy = (since > 0 && since < 220) ? 1 - 0.18 * bell(since / 220) : 1
            let sx = 1 / pow(sy, 0.6)
            let bob = 0.8 * wave(idle, period: 2600, phase: Double(i) * 0.21) * live
            var dc = c
            dc.translateBy(x: hub.x + date.0, y: hub.y + date.1 + fall + bob + 7)
            dc.scaleBy(x: sx, y: sy)
            piece(dc, 1.6, Path(ellipseIn: CGRect(x: -5.2, y: -14.4, width: 10.4, height: 14.8)), date.2)
        }
    }

    // MARK: Title and tag

    private var titleY: CGFloat { baseY + 86 }

    private func drawTitle(_ ctx: GraphicsContext) {
        let letters = Array("Kheir").map(String.init)
        let font = Font.system(size: 46, weight: .black, design: .rounded)
        let backs = letters.map { ctx.resolve(Text($0).font(font).foregroundStyle(Self.terracotta)) }
        let faces = letters.map { ctx.resolve(Text($0).font(font).foregroundStyle(Self.cream)) }
        let widths = faces.map { $0.measure(in: CGSize(width: 200, height: 200)).width }
        let gap: CGFloat = 4
        var x = cx - (widths.reduce(0, +) + gap * CGFloat(letters.count - 1)) / 2
        for i in letters.indices {
            let (a, st, du) = LoadingBeats.letters
            let t0 = a + Double(i) * st
            let p = seg(build, t0, t0 + du)
            if p > 0 {
                let tilt = (seeded(i, salt: 77) - 0.5) * 7
                var c = ctx
                c.translateBy(x: x + widths[i] / 2, y: titleY - 16 - CGFloat(1 - p) * 12)
                c.rotate(by: .degrees(tilt))
                let sc = 1 + (1 - p) * 0.08
                c.scaleBy(x: sc, y: sc)
                c.opacity = min(1, p * 2.5)
                let d = 0.9 + (1 - p) * 2.4
                // Terracotta backing: the face text spread a few points all round, cut as one piece.
                c.drawLayer { layer in
                    layer.addFilter(.shadow(color: Color(red: 0.04, green: 0.12, blue: 0.05).opacity(0.45), radius: (2 + 3 * d) / 2, x: 1.2 * d, y: 2.2 * d))
                    layer.drawLayer { back in
                        for k in 0..<12 {
                            let ang = Double(k) / 12 * 2 * .pi
                            back.draw(backs[i], at: CGPoint(x: 3.5 * cos(ang), y: 3.5 * sin(ang)), anchor: .center)
                        }
                        back.draw(backs[i], at: .zero, anchor: .center)
                    }
                }
                c.draw(faces[i], at: CGPoint(x: -1, y: -1), anchor: .center)
            }
            x += widths[i] + gap
        }
    }

    private func drawTag(_ ctx: GraphicsContext) {
        let tp = seg(build, LoadingBeats.tag.0, LoadingBeats.tag.1)
        guard tp > 0 else { return }
        var c = ctx
        c.translateBy(x: cx + CGFloat(1 - tp) * -(W + 120), y: titleY + 40)
        c.rotate(by: .degrees(-2))
        let w2: CGFloat = 58, h2: CGFloat = 22
        var tag = Path()
        tag.move(to: CGPoint(x: -w2, y: -h2))
        for k in 0...24 { tag.addLine(to: CGPoint(x: -w2 + CGFloat(k) * w2 * 2 / 24, y: -h2 + jitter(k, 81))) }
        for k in 0...8 { tag.addLine(to: CGPoint(x: w2 + jitter(k, 82), y: -h2 + CGFloat(k) * h2 * 2 / 8)) }
        for k in stride(from: 24, through: 0, by: -1) { tag.addLine(to: CGPoint(x: -w2 + CGFloat(k) * w2 * 2 / 24, y: h2 + jitter(k, 83))) }
        for k in stride(from: 8, through: 0, by: -1) { tag.addLine(to: CGPoint(x: -w2 + jitter(k, 84), y: -h2 + CGFloat(k) * h2 * 2 / 8)) }
        tag.closeSubpath()
        piece(c, 0.9, tag, Self.mustard)
        let arabic = c.resolve(Text("خَيْر").font(.custom("ScheherazadeNew-Regular", size: 28)).foregroundStyle(Self.table))
        c.draw(arabic, at: CGPoint(x: 0, y: 1), anchor: .center)
        // A strip of tape holds the tag's left corner.
        var tape = c
        tape.rotate(by: .degrees(-6))
        tape.fill(Path(CGRect(x: -w2 - 10, y: -h2 - 4, width: 26, height: 10)), with: .color(Self.cream.opacity(0.55)))
    }

    private func jitter(_ k: Int, _ salt: Double) -> CGFloat { CGFloat(seeded(k, salt: salt) - 0.5) * 3 }

    // MARK: Loading indicator

    /// Three paper dates hop in turn: stretch in the air, squash on landing.
    private func drawHoppingDates(_ ctx: GraphicsContext) {
        // On a returning launch the dates are part of the first frame; on the first launch they arrive after the build.
        let lp = loadFrom == 0 ? 1 : seg(build, LoadingBeats.load, LoadingBeats.load + 300)
        guard lp > 0 else { return }
        for i in 0..<3 {
            let ph = loop(idle, period: 1170, phase: -Double(i) * 0.16)
            let air = ph < 0.42 ? sin(ph / 0.42 * .pi) : 0
            let land = (ph >= 0.42 && ph < 0.55) ? bell((ph - 0.42) / 0.13) : 0
            let sy = 1 + 0.12 * air - 0.18 * land
            let sx = 1 / pow(sy, 0.6)
            var c = ctx
            c.opacity = lp
            c.translateBy(x: cx + CGFloat(i - 1) * 20, y: titleY + 92 - CGFloat(air) * 10)
            c.scaleBy(x: sx, y: sy)
            piece(c, 1 + CGFloat(air) * 1.5, Path(ellipseIn: CGRect(x: -4.4, y: -10.8, width: 8.8, height: 11.6)), i == 1 ? Self.dateB : Self.dateA)
        }
    }

    // MARK: - Pieces and shapes

    /// A paper piece on the table: a soft cast shadow and a tight contact shadow, both growing with depth.
    private func piece(_ ctx: GraphicsContext, _ depth: CGFloat, _ path: Path, _ color: Color) {
        var cast = ctx
        cast.addFilter(.shadow(color: Color(red: 0.08, green: 0.04, blue: 0.02).opacity(0.22), radius: (5 + 5 * depth) / 2, x: 1.4 * depth, y: 2.6 * depth))
        cast.addFilter(.shadow(color: Color(red: 0.1, green: 0.05, blue: 0.02).opacity(0.3), radius: (1.4 + depth) / 2, x: 0.5 * depth, y: depth))
        cast.fill(path, with: .color(color))
    }

    private func brass(_ ctx: GraphicsContext, center: CGPoint, radius: CGFloat) {
        let rect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
        ctx.fill(Path(ellipseIn: rect), with: .radialGradient(
            Gradient(stops: [.init(color: Color(hex: "#F6DE93"), location: 0), .init(color: Color(hex: "#C79A3A"), location: 0.6), .init(color: Color(hex: "#7E5A1C"), location: 1)]),
            center: CGPoint(x: center.x - radius * 0.3, y: center.y - radius * 0.3), startRadius: 0, endRadius: radius * 1.2))
    }

    private func dune(top: CGFloat, amp: CGFloat, seed: Int, offset: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -10, y: H + 10))
        let pa = seeded(seed, salt: 61) * 6.28, pb = seeded(seed, salt: 62) * 6.28
        var k = 0
        while CGFloat(k * 4) < W + 16 {
            let x = CGFloat(k * 4 - 8)
            let roll = sin(Double(x) / 70 + pa) + 0.3 * sin(Double(x) / 23 + pb)
            let rag = (seeded(k, salt: Double(seed) + 63) - 0.5) * 1.8
            p.addLine(to: CGPoint(x: x, y: top + offset + CGFloat(roll) * amp + CGFloat(rag)))
            k += 1
        }
        p.addLine(to: CGPoint(x: W + 10, y: H + 10))
        p.closeSubpath()
        return p
    }

    private func cutCircle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, seed: Int) -> Path {
        var p = Path()
        let ph = seeded(seed, salt: 31) * 6.28
        for k in 0...48 {
            let a = Double(k) / 48 * 2 * .pi
            let rr = Double(r) + 0.5 * sin(a * 3 + ph) + 0.3 * sin(a * 7 + ph * 2)
            let pt = CGPoint(x: x + cos(a) * rr, y: y + sin(a) * rr)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    /// A crescent cut as ONE outline: the outer circle minus a bite circle offset by (bx, by).
    private func crescent(cx: CGFloat, cy: CGFloat, r: CGFloat, bx: CGFloat, by: CGFloat, br: CGFloat) -> Path {
        let ax = atan2(-Double(by), -Double(bx))
        var outer: [CGPoint] = [], inner: [CGPoint] = []
        for k in 0...160 {
            let a = ax - .pi + Double(k) / 160 * 2 * .pi
            let o = CGPoint(x: cx + cos(a) * r, y: cy + sin(a) * r)
            if hypot(o.x - cx - bx, o.y - cy - by) >= br { outer.append(o) }
            let b = CGPoint(x: cx + bx + cos(a) * br, y: cy + by + sin(a) * br)
            if hypot(b.x - cx, b.y - cy) <= r { inner.append(b) }
        }
        var p = Path()
        p.addLines(outer + inner.reversed())
        p.closeSubpath()
        return p
    }

    private func star(x: CGFloat, y: CGFloat, r: CGFloat, rot: Double) -> Path {
        var p = Path()
        for k in 0..<10 {
            let a = (Double(k) * 36 + rot - 90) * .pi / 180
            let rr = k % 2 == 1 ? r * 0.45 : r
            let pt = CGPoint(x: x + cos(a) * rr, y: y + sin(a) * rr)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    /// A palm frond: curved midrib drooping toward the tip, serrated cut edge, ONE outline.
    private func frondPath(length: CGFloat, width: CGFloat, seed: Int) -> Path {
        let n = 11
        var up: [CGPoint] = [], dn: [CGPoint] = []
        for i in 0...n {
            let f = CGFloat(i) / CGFloat(n)
            let x = f * length
            let y = sin(f * .pi * 0.9) * -width * 0.15 + f * f * width * 0.9
            let w = width * sin(.pi * min(1, f * 1.1)) * (0.6 + 0.4 * (1 - f))
            let notch: CGFloat = i % 2 == 1 ? 0.55 : 1
            up.append(CGPoint(x: x, y: y - w * 0.35))
            dn.append(CGPoint(x: x + (i % 2 == 1 ? 3 : 0), y: y + w * notch * (0.9 + CGFloat(seeded(i, salt: Double(seed))) * 0.2)))
        }
        var p = Path()
        p.move(to: .zero)
        for q in up { p.addLine(to: q) }
        for q in dn.reversed() { p.addLine(to: q) }
        p.closeSubpath()
        return p
    }
}

#Preview("Loading, first launch") {
    PaperLoadingScene(playsBuild: true)
}

#Preview("Loading, returning") {
    PaperLoadingScene(playsBuild: false)
}
