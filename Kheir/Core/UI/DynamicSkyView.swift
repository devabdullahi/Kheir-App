import SwiftUI

// MARK: - DynamicSkyView

/// The sky as a cut-paper diorama, animated smoothly on one clock.
///
/// Layers, back to front (depth = shadow, see `PaperKit`):
/// 1. sky bands: one torn strip per gradient colour, glued down (no motion);
/// 2. paper stars that twinkle by a small scale step, at seeded times;
/// 3. a crescent moon hanging on a thread, rocking gently;
/// 4. the sun: a tissue-paper glow, two rings of cut rays turning slowly, two discs;
/// 5. paper clouds drifting across in parallax (further = slower);
/// 6. torn hills with a small masjid cut-out.
///
/// The view owns no engine: callers feed it a `SkyState` (updated every 30 s).
/// One clock drives everything. Reduce Motion freezes at frame 0, which is a
/// complete drawing; the clock is paused while the view is off screen.
///
/// ```swift
/// DynamicSkyView(skyState: engine.currentState)
///     .frame(height: DesignTokens.skyHeaderHeight)
/// ```
struct DynamicSkyView: View {

    let skyState: SkyState
    /// Draw the foreground hills. Off for full-screen backdrops where content covers the bottom.
    var showsHills = true

    @State private var isVisible = false
    @State private var isOnScreen = true
    @Environment(\.scenePhase) private var scenePhase

    /// The sky plays when it appears (and when the app returns), then comes to rest on
    /// its last frame: any ticking animation makes the whole screen repaint, so an
    /// always-moving sky cost ~7% CPU at idle on Home.
    @State private var resting = false
    static let playSeconds: Double = 20

    var body: some View {
        let paused = !isVisible || !isOnScreen || scenePhase != .active || resting
        // Only the pieces that move are redrawn on the clock. The torn sky bands, the
        // hills, the masjid and the back garden rows are drawn once per sky state.
        ZStack {
            Canvas { context, size in
                PaperSkyScene(state: skyState, size: size, t: 0).drawBands(context)
            }
            // Sun rays, moon and clouds at a full 60 fps while the sky plays.
            LoopClock(period: Tokens.loop, paused: paused, fps: 60) { t in
                Canvas { context, size in
                    let scene = PaperSkyScene(state: skyState, size: size, t: t, moving: true)
                    scene.drawStars(context)
                    scene.drawMoon(context)
                    scene.drawSun(context)
                    scene.drawClouds(context)
                }
            }
            if showsHills {
                Canvas { context, size in
                    PaperSkyScene(state: skyState, size: size, t: 0).drawHills(context)
                }
                // The garden stands still: ~20 flowers with shadows redrawn every frame
                // were the most expensive thing on Home.
                Canvas { context, size in
                    PaperSkyScene(state: skyState, size: size, t: 0).drawFrontGarden(context)
                }
            }
        }
        .overlay {
            // Plain overlay (no blend mode): blending over a moving layer forces an
            // offscreen pass every frame.
            PaperGrain(material: .construction, seed: 12, dark: skyState.starOpacity > 0.5)
                .opacity(0.7)
        }
        .animation(.travel(2.0), value: skyState.sunPosition.y)
        .clipped()
        .task(id: isVisible && scenePhase == .active) {
            guard isVisible, scenePhase == .active else { return }
            resting = false
            try? await Task.sleep(for: .seconds(Self.playSeconds))
            resting = true
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        // Scrolled out of view (e.g. Home scrolled down): stop the clock.
        .onScrollVisibilityChange(threshold: 0.01) { isOnScreen = $0 }
        .accessibilityHidden(true)  // purely decorative — screen readers skip this
    }

    /// Every number of the scene in one place: "slower" or "smaller" is a one-line change.
    enum Tokens {
        /// Master loop (ms). Every period below divides it, so the loop never jumps.
        static let loop: Double = 120_000
        static let bandCount = 5
        static let bandTear: CGFloat = 5
        static let sunRayTurn: Double = 60_000        // one full turn of the outer rays
        static let sunInnerTurn: Double = 40_000      // inner rays, the other way
        static let sunBob: CGFloat = 1.6
        static let sunBobPeriod: Double = 4_000
        static let moonRock: Double = 2.5             // degrees
        static let moonRockPeriod: Double = 5_000
        static let starTwinkle: Double = 0.18         // scale dip
        static let cloudPeriods: [Double] = [120_000, 60_000, 40_000] // far → near
        static let hillHeight: CGFloat = 0.2          // fraction of the canvas
        static let skyTop: CGFloat = 62               // pt: just below the status bar / Dynamic Island
        static let skyBand: CGFloat = 210             // pt of sky the sun, moon and clouds move within
    }
}

// MARK: - Scene

/// Pure function of (state, size, t): no state carried between frames.
private struct PaperSkyScene {
    typealias T = DynamicSkyView.Tokens

    let state: SkyState
    let size: CGSize
    let t: Double
    /// Pieces redrawn every frame get one combined soft shadow instead of two blurs.
    var moving = false

    /// 0 at noon, 1 deep at night. Tints clouds and hills.
    var night: Double { min(1, max(0, state.starOpacity)) }
    /// Loose pieces used to be nudged per photo (stop motion); motion is smooth now.
    func nudge(_ key: Int) -> CGSize { .zero }

    /// Maps a 0…1 sky height to points measured from the top of the screen: a fixed
    /// band starting just below the status bar and Dynamic Island. Fixed points (not a
    /// fraction of the canvas) so the sun, moon and clouds sit in the same place on
    /// Home's short sky and Prayer Times' full-screen sky.
    func skyY(_ fraction: CGFloat) -> CGFloat {
        let band = min(size.height - T.skyTop, T.skyBand)
        return T.skyTop + fraction * band
    }

    // MARK: Shadow helper

    /// Draws `body` on its own layer with a two-part paper shadow scaled by `depth`.
    func piece(_ ctx: GraphicsContext, depth: CGFloat, _ body: (inout GraphicsContext) -> Void) {
        if moving {
            ctx.drawLayer { layer in
                layer.addFilter(.shadow(color: Color(red: 0.11, green: 0.05, blue: 0.02).opacity(0.32), radius: 1.4 + 1.6 * depth, x: 0.9 * depth, y: 1.8 * depth))
                body(&layer)
            }
            return
        }
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: Color(red: 0.12, green: 0.06, blue: 0.02).opacity(0.28), radius: 0.8 + 0.5 * depth, x: 0.5 * depth, y: 1 * depth))
            layer.addFilter(.shadow(color: Color(red: 0.10, green: 0.05, blue: 0.02).opacity(0.18), radius: 2.5 + 2.5 * depth, x: 1.4 * depth, y: 2.6 * depth))
            body(&layer)
        }
    }

    // MARK: 1. Sky bands

    func drawBands(_ ctx: GraphicsContext) {
        let colors = state.gradientColors
        guard let first = colors.first else { return }
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(first))

        // Each later colour is a torn strip laid over the one above it.
        let count = max(colors.count - 1, 1)
        for k in 1..<max(colors.count, 2) where k < colors.count {
            let y = size.height * CGFloat(k) / CGFloat(count + 1) * 1.05
            let edge = PaperNoise.tornLine(width: size.width, y: y, amplitude: T.bandTear, seed: 200 + k)
            var strip = Path()
            strip.move(to: CGPoint(x: -10, y: size.height + 10))
            for p in edge { strip.addLine(to: p) }
            strip.addLine(to: CGPoint(x: size.width + 10, y: size.height + 10))
            strip.closeSubpath()
            piece(ctx, depth: 0.35) { layer in
                layer.fill(strip, with: .color(colors[k]))
            }
        }
    }

    // MARK: 2. Stars

    func drawStars(_ ctx: GraphicsContext) {
        guard state.starOpacity > 0.01 else { return }
        var layer = ctx
        layer.opacity = state.starOpacity
        for i in 0..<9 {
            let x = (0.06 + seeded(i, salt: 11) * 0.88) * size.width
            let y = (0.06 + seeded(i, salt: 12) * 0.42) * size.height
            let r = 2.6 + seeded(i, salt: 13) * 2.6
            // Twinkle: a short dip in scale at a seeded moment of each 3–5 s beat.
            let beat = 3000 + seeded(i, salt: 14) * 2000
            let p = loop(t, period: beat, phase: seeded(i, salt: 15))
            let dip = p < 0.12 ? bell(p / 0.12) : 0
            let scale = 1 - T.starTwinkle * dip
            let star = Self.star(center: CGPoint(x: x, y: y), radius: r * scale, rotation: seeded(i, salt: 16) * 72)
            piece(layer, depth: 0.6) { l in
                l.fill(star, with: .color(Color(hex: "#FFF4D6")))
            }
        }
    }

    // MARK: 3. Moon

    func drawMoon(_ ctx: GraphicsContext) {
        guard state.moonOpacity > 0.01 else { return }
        var layer = ctx
        layer.opacity = state.moonOpacity

        let anchor = CGPoint(x: state.moonPosition.x * size.width, y: -4)
        let hang = max(24, skyY(state.moonPosition.y))
        let swing = Angle.degrees(T.moonRock * wave(t, period: T.moonRockPeriod))
        let n = nudge(3)

        layer.translateBy(x: anchor.x + n.width, y: anchor.y)
        layer.rotate(by: swing)

        // The knot sits on the top edge straight above the crescent's centre of mass
        // (about 0.35r left of the disc centre), so it hangs balanced under the thread.
        let r: CGFloat = 15
        let knot = hang - r
        let centre = CGPoint(x: r * 0.34, y: knot + r * 0.94)
        var thread = Path()
        thread.move(to: .zero)
        thread.addLine(to: CGPoint(x: 0, y: knot + 2))
        layer.stroke(thread, with: .color(Color(hex: "#F3E9D2").opacity(0.55)), lineWidth: 0.7)

        // Crescent cut as ONE outline (a disc minus a disc), so no seam shows.
        let disc = Path(ellipseIn: CGRect(x: centre.x - r, y: centre.y - r, width: r * 2, height: r * 2))
        let bite = Path(ellipseIn: CGRect(x: centre.x - r + r * 0.48, y: centre.y - r - r * 0.18, width: r * 2, height: r * 2))
        let crescent = disc.subtracting(bite)
        piece(layer, depth: 2.2) { l in
            l.fill(crescent, with: .color(Color(hex: "#F6EBC8")))
        }
        // A brad where the thread pierces the paper.
        layer.fill(Path(ellipseIn: CGRect(x: -1.6, y: knot + 2.4 - 1.6, width: 3.2, height: 3.2)), with: .color(Color(hex: "#C79A3A")))
    }

    // MARK: 4. Sun

    func drawSun(_ ctx: GraphicsContext) {
        guard state.sunOpacity > 0.01 else { return }
        var layer = ctx
        layer.opacity = state.sunOpacity

        let n = nudge(5)
        let bob = T.sunBob * CGFloat(wave(t, period: T.sunBobPeriod))
        let c = CGPoint(x: state.sunPosition.x * size.width + n.width, y: skyY(state.sunPosition.y) + bob + n.height)
        let core = state.sunSize / 2 + 4

        // Tissue-paper glow: two translucent circles, not a gradient.
        for (k, f) in [(0, 1.0), (1, 0.7)] {
            let gr = state.sunGlowRadius * CGFloat(f) + core * 0.6
            var tissue = layer
            tissue.opacity = 0.42
            piece(tissue, depth: 0.4) { l in
                l.fill(Path(ellipseIn: CGRect(x: c.x - gr, y: c.y - gr, width: gr * 2, height: gr * 2)).applying(.identity),
                       with: .color(state.sunGlowColor.opacity(k == 0 ? 0.55 : 0.8)))
            }
        }

        // Outer rays: 12 cut petals, slightly uneven like hand-cut paper, turning slowly.
        let outerTurn = Angle.degrees(360 * loop(t, period: T.sunRayTurn))
        let outer = Self.rays(count: 12, center: c, inner: core * 0.9, outer: core * 1.75, width: 0.36, rotation: outerTurn, seed: 1)
        piece(layer, depth: 1.6) { l in
            l.fill(outer, with: .color(Color(hex: "#F2A93B")))
        }
        // Inner rays turn the other way, in a lighter paper.
        let innerTurn = Angle.degrees(-360 * loop(t, period: T.sunInnerTurn) + 15)
        let inner = Self.rays(count: 12, center: c, inner: core * 0.8, outer: core * 1.38, width: 0.3, rotation: innerTurn, seed: 2)
        piece(layer, depth: 1.8) { l in
            l.fill(inner, with: .color(Color(hex: "#FFD36B")))
        }
        // Two discs, each a separate piece with its own shadow.
        let disc = Self.cutCircle(center: c, radius: core, seed: 3)
        piece(layer, depth: 2.0) { l in
            l.fill(disc, with: .color(Color(hex: "#F7B733")))
        }
        let face = Self.cutCircle(center: CGPoint(x: c.x - core * 0.08, y: c.y - core * 0.08), radius: core * 0.68, seed: 4)
        piece(layer, depth: 2.2) { l in
            l.fill(face, with: .color(Color(hex: "#FFE08A")))
        }
    }

    // MARK: 5. Clouds

    func drawClouds(_ ctx: GraphicsContext) {
        let day = 1 - night * 0.75
        let paper = Color(hex: "#FFFDF6").mix(with: Color(hex: "#5B6690"), by: night * 0.7)
        for i in 0..<3 {
            let period = T.cloudPeriods[i]
            let w = (54 + CGFloat(i) * 22) * (0.9 + CGFloat(seeded(i, salt: 21)) * 0.2)
            let travel = size.width + w * 2
            let x = CGFloat(loop(t, period: period, phase: seeded(i, salt: 22))) * travel - w
            // Clouds keep to the upper sky, clear of the countdown below.
            let y = skyY(0.10 + CGFloat(i) * 0.08 + CGFloat(seeded(i, salt: 23)) * 0.04)
            let n = nudge(30 + i)
            let cloud = Self.cloud(center: CGPoint(x: x + n.width, y: y + n.height), width: w, seed: i)
            var layer = ctx
            layer.opacity = 0.92 * day + 0.25
            piece(layer, depth: 0.9 + CGFloat(i) * 0.5) { l in
                l.fill(cloud, with: .color(paper))
            }
        }
    }

    // MARK: 6. Hills

    func drawHills(_ ctx: GraphicsContext) {
        let farGreen = Color(hex: "#7FAE7A").mix(with: Color(hex: "#1D2A3E"), by: night * 0.8)
        let nearGreen = Color(hex: "#4E8A5A").mix(with: Color(hex: "#141E2E"), by: night * 0.8)
        let hillTop = size.height * (1 - T.hillHeight)

        let far = Self.hill(size: size, top: hillTop, amplitude: 9, seed: 300)
        piece(ctx, depth: 0.7) { l in l.fill(far, with: .color(farGreen)) }

        // The masjid sits on the far hill, cut from the near hill's paper.
        let mx = size.width * 0.72
        let masjid = Self.masjid(base: CGPoint(x: mx, y: hillTop + 6), scale: 1)
        piece(ctx, depth: 0.8) { l in l.fill(masjid, with: .color(nearGreen.mix(with: .black, by: 0.25))) }

        // The garden: one flower per past day, back rows smaller (parallax depth).
        plantRow(ctx, top: hillTop, amplitude: 9, seed: 300, spacing: 13, size: 11, depth: 0.5, avoid: mx + 5, dayOffset: 30)
        plantRow(ctx, top: hillTop + size.height * 0.04, amplitude: 8, seed: 302, spacing: 16, size: 15, depth: 0.7, avoid: mx + 5, dayOffset: 16)

        let near = Self.hill(size: size, top: hillTop + size.height * 0.08, amplitude: 7, seed: 301)
        piece(ctx, depth: 1.0) { l in l.fill(near, with: .color(nearGreen)) }
    }

    /// The front row of flowers: the only part of the hills that sways, so it is the
    /// only part redrawn on the clock.
    func drawFrontGarden(_ ctx: GraphicsContext) {
        let hillTop = size.height * (1 - T.hillHeight)
        plantRow(ctx, top: hillTop + size.height * 0.08, amplitude: 7, seed: 301, spacing: 19, size: 20, depth: 1.0, avoid: nil, dayOffset: 0)
    }

    /// The ridge line of `hill(...)` without its ragged tear, so flowers stand on the paper.
    static func hillY(_ x: CGFloat, top: CGFloat, amplitude: CGFloat, seed: Int) -> CGFloat {
        let phaseA: Double = seeded(seed, salt: 61) * 6.28
        let phaseB: Double = seeded(seed, salt: 62) * 6.28
        let roll: Double = sin(Double(x) / 90 + phaseA) + 0.35 * sin(Double(x) / 37 + phaseB)
        return top + CGFloat(roll) * amplitude
    }

    /// A row of planted flowers. Each sways around its stem base; the phase drifts with x
    /// so a breeze travels across the field. One shadowed layer for the whole row.
    func plantRow(_ ctx: GraphicsContext, top: CGFloat, amplitude: CGFloat, seed: Int, spacing: CGFloat, size flowerSize: CGFloat, depth: CGFloat, avoid: CGFloat?, dayOffset: Int) {
        let count = max(1, Int(size.width / spacing))
        let today = DailyFlower.dayNumber(.now)
        piece(ctx, depth: depth) { layer in
            for k in 0..<count {
                let x = (CGFloat(k) + 0.5 + CGFloat(seeded(k, salt: Double(seed) + 7) - 0.5) * 0.7) / CGFloat(count) * size.width
                if let avoid, abs(x - avoid) < 34 { continue }
                let s = flowerSize * CGFloat(0.8 + seeded(k, salt: Double(seed) + 8) * 0.4)
                let y = Self.hillY(x, top: top, amplitude: amplitude, seed: seed) + 3 + CGFloat(seeded(k, salt: Double(seed) + 9)) * 5
                let amp = 1.8 + seeded(k, salt: Double(seed) + 10) * 2.2
                let period = 3_600 + seeded(k, salt: Double(seed) + 11) * 2_200
                let sway = amp * wave(t, period: period, phase: seeded(k, salt: Double(seed) + 12) + Double(x / size.width) * 0.35)
                let flower = DailyFlower.forDay(today - dayOffset - k)
                var c = layer
                c.translateBy(x: x, y: y)
                c.rotate(by: .degrees(flower.tilt + sway))
                c.opacity = 1 - night * 0.45
                FlowerArt.draw(flower, in: c, size: s)
            }
        }
    }

    // MARK: - Shapes

    static func star(center c: CGPoint, radius r: CGFloat, rotation: Double) -> Path {
        var p = Path()
        for k in 0..<10 {
            let a = (Double(k) * 36 + rotation - 90) * .pi / 180
            let rr = k.isMultiple(of: 2) ? r : r * 0.45
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    /// A circle cut by scissors: a gentle wobble of the radius.
    static func cutCircle(center c: CGPoint, radius r: CGFloat, seed: Int) -> Path {
        var p = Path()
        let steps = 48
        for k in 0...steps {
            let a = Double(k) / Double(steps) * .pi * 2
            let phase: Double = seeded(seed, salt: 31) * 6.28
            let wobble: Double = 0.5 * sin(a * 3 + phase) + 0.3 * sin(a * 7 + phase * 2)
            let rr = r + CGFloat(wobble)
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * rr, y: c.y + CGFloat(sin(a)) * rr)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        p.closeSubpath()
        return p
    }

    /// A ring of petal rays, each its own subpath (filled together; they never overlap).
    static func rays(count: Int, center c: CGPoint, inner: CGFloat, outer: CGFloat, width: Double, rotation: Angle, seed: Int) -> Path {
        var p = Path()
        for k in 0..<count {
            let base = Double(k) / Double(count) * .pi * 2 + rotation.radians
            let len = outer * CGFloat(0.9 + seeded(k, salt: Double(seed) + 41) * 0.2)
            let half = width / 2 * (0.85 + seeded(k, salt: Double(seed) + 42) * 0.3)
            let tip = CGPoint(x: c.x + CGFloat(cos(base)) * len, y: c.y + CGFloat(sin(base)) * len)
            let l = CGPoint(x: c.x + CGFloat(cos(base - half)) * inner, y: c.y + CGFloat(sin(base - half)) * inner)
            let r = CGPoint(x: c.x + CGFloat(cos(base + half)) * inner, y: c.y + CGFloat(sin(base + half)) * inner)
            p.move(to: l)
            p.addQuadCurve(to: tip, control: CGPoint(x: (l.x + tip.x) / 2 + CGFloat(sin(base)) * 1.5, y: (l.y + tip.y) / 2 - CGFloat(cos(base)) * 1.5))
            p.addLine(to: r)
            p.closeSubpath()
        }
        return p
    }

    /// Puffs unioned into ONE outline with a flat-ish base, like a cut cloud.
    static func cloud(center c: CGPoint, width w: CGFloat, seed: Int) -> Path {
        let h = w * 0.42
        var shape = Path(roundedRect: CGRect(x: c.x - w / 2, y: c.y - h * 0.15, width: w, height: h * 0.5), cornerRadius: h * 0.25)
        let puffs: [(CGFloat, CGFloat, CGFloat)] = [(-0.28, 0.0, 0.26), (-0.02, -0.18, 0.34), (0.26, -0.04, 0.27)]
        for (k, puff) in puffs.enumerated() {
            let r = w * puff.2 * CGFloat(0.92 + seeded(seed * 3 + k, salt: 51) * 0.16)
            let circle = cutCircle(center: CGPoint(x: c.x + w * puff.0, y: c.y + h * puff.1), radius: r, seed: seed * 3 + k)
            shape = shape.union(circle)
        }
        return shape
    }

    static func hill(size: CGSize, top: CGFloat, amplitude: CGFloat, seed: Int) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -10, y: size.height + 10))
        let steps = Int(size.width / 4) + 4
        for k in 0...steps {
            let x = CGFloat(k) * 4 - 8
            let phaseA: Double = seeded(seed, salt: 61) * 6.28
            let phaseB: Double = seeded(seed, salt: 62) * 6.28
            let roll: Double = sin(Double(x) / 90 + phaseA) * 1.0 + sin(Double(x) / 37 + phaseB) * 0.35
            let rag: Double = (seeded(k, salt: Double(seed) + 63) - 0.5) * 1.6
            p.addLine(to: CGPoint(x: x, y: top + CGFloat(roll) * amplitude + CGFloat(rag)))
        }
        p.addLine(to: CGPoint(x: size.width + 10, y: size.height + 10))
        p.closeSubpath()
        return p
    }

    /// A small masjid silhouette: a dome on a drum, a minaret with a crescent finial.
    static func masjid(base b: CGPoint, scale s: CGFloat) -> Path {
        var hall = Path(CGRect(x: b.x - 18 * s, y: b.y - 14 * s, width: 36 * s, height: 16 * s))
        var dome = Path()
        dome.move(to: CGPoint(x: b.x - 12 * s, y: b.y - 14 * s))
        dome.addCurve(to: CGPoint(x: b.x, y: b.y - 33 * s), control1: CGPoint(x: b.x - 13 * s, y: b.y - 25 * s), control2: CGPoint(x: b.x - 5 * s, y: b.y - 30 * s))
        dome.addCurve(to: CGPoint(x: b.x + 12 * s, y: b.y - 14 * s), control1: CGPoint(x: b.x + 5 * s, y: b.y - 30 * s), control2: CGPoint(x: b.x + 13 * s, y: b.y - 25 * s))
        dome.closeSubpath()
        let spire = Path(CGRect(x: b.x - 0.6 * s, y: b.y - 38 * s, width: 1.2 * s, height: 6 * s))
        let minaret = Path(CGRect(x: b.x + 22 * s, y: b.y - 38 * s, width: 5 * s, height: 40 * s))
        var cap = Path()
        cap.move(to: CGPoint(x: b.x + 21 * s, y: b.y - 38 * s))
        cap.addLine(to: CGPoint(x: b.x + 24.5 * s, y: b.y - 46 * s))
        cap.addLine(to: CGPoint(x: b.x + 28 * s, y: b.y - 38 * s))
        cap.closeSubpath()
        hall = hall.union(dome).union(spire).union(minaret).union(cap)
        return hall
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Fajr") {
    DynamicSkyView(skyState: .fajr)
        .frame(height: DesignTokens.skyHeaderHeight)
}

#Preview("Dhuhr") {
    DynamicSkyView(skyState: .dhuhr)
        .frame(height: DesignTokens.skyHeaderHeight)
}

#Preview("Maghrib") {
    DynamicSkyView(skyState: .maghrib)
        .frame(height: DesignTokens.skyHeaderHeight)
}

#Preview("Isha") {
    DynamicSkyView(skyState: .isha)
        .frame(height: DesignTokens.skyHeaderHeight)
}

#Preview("Interpolated — Fajr → Sunrise 50%") {
    DynamicSkyView(
        skyState: SkyState.interpolate(from: .fajr, to: .sunrise, progress: 0.5)
    )
    .frame(height: DesignTokens.skyHeaderHeight)
}
#endif
