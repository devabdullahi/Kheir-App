import SwiftUI
import Synchronization

// MARK: - Paper Icons
//
// Every icon in the app is a small cut-paper piece with its own calm idle motion
// (suns rise and turn, the moon rocks, the bell rings in bursts). Screens use
// `PaperIconView(.asr)` and never draw icons themselves, so the art can evolve
// in one place. Widgets and Live Activities pass `animated: false`, because iOS
// doesn't run custom animation there.
//
// The art is drawn in a 24×24 design space (the same numbers as the approved
// SVG mockup). Each part is a flat piece of coloured paper; parts that sit on top
// of another piece are "lifted" and cast a tiny shadow toward the bottom right.

enum PaperIcon: String, CaseIterable, Sendable {
    // Tabs and navigation
    case house, book, bookmark, compass, clock, gear, search, share, plus, aa
    // Prayers and sky
    case fajr, sunrise, dhuhr, asr, maghrib, isha, sun, moon, star
    // Practice and progress
    case sprout, beads, pen, bell, lantern
    // Places and trust
    case masjid, pin, shield, widget
    // Player
    case play, pause, previous, next

    /// The icon for a prayer name as it appears in prayer data ("Fajr", "Sunrise", …).
    static func forPrayer(_ name: String) -> PaperIcon {
        switch name.lowercased() {
        case "fajr": .fajr
        case "sunrise", "shuruq": .sunrise
        case "dhuhr", "zuhr", "jumuah", "jumu'ah": .dhuhr
        case "asr": .asr
        case "maghrib": .maghrib
        case "isha": .isha
        default: .sun
        }
    }

    /// SF Symbol for places that can't draw the paper art (menus, system UI).
    var fallbackSymbol: String {
        switch self {
        case .house: "house.fill"
        case .book: "book.fill"
        case .bookmark: "bookmark.fill"
        case .compass: "safari.fill"
        case .clock: "clock.fill"
        case .gear: "gearshape.fill"
        case .search: "magnifyingglass"
        case .share: "square.and.arrow.up"
        case .plus: "plus"
        case .aa: "textformat.size"
        case .fajr: "sunrise.fill"
        case .sunrise: "sun.horizon.fill"
        case .dhuhr, .sun: "sun.max.fill"
        case .asr: "sun.haze.fill"
        case .maghrib: "sunset.fill"
        case .isha, .moon: "moon.stars.fill"
        case .star: "star.fill"
        case .sprout: "leaf.fill"
        case .beads: "circle.dotted"
        case .pen: "pencil"
        case .bell: "bell.fill"
        case .lantern: "lamp.desk.fill"
        case .masjid: "building.columns.fill"
        case .pin: "mappin"
        case .shield: "lock.shield.fill"
        case .widget: "square.grid.2x2.fill"
        case .play: "play.fill"
        case .pause: "pause.fill"
        case .previous: "backward.end.fill"
        case .next: "forward.end.fill"
        }
    }

    /// Length (ms) of the icon's idle loop, chosen so every part's own cycle fits
    /// a whole number of times. `nil` for icons that stay still.
    var motionPeriod: Double? {
        switch self {
        case .fajr, .sunrise: 8_400
        case .dhuhr, .sun: 24_000
        case .asr: 330_000
        case .maghrib: 9_200
        case .isha, .moon: 10_000
        case .bell: 3_200
        case .clock: 72_000
        case .compass: 5_200
        case .pin: 1_800
        case .star: 3_400
        case .beads: 2_400
        case .pen: 1_000
        case .sprout: 28_800
        case .lantern: 8_400
        case .gear: 14_000
        case .bookmark: 6_800
        case .book: 7_200
        case .house, .search, .share, .plus, .aa, .masjid, .shield, .widget,
             .play, .pause, .previous, .next: nil
        }
    }
}

/// A paper icon. `animated: false` for widgets, Live Activities and share images.
struct PaperIconView: View {
    let icon: PaperIcon
    var size: CGFloat = 22
    var animated: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    init(_ icon: PaperIcon, size: CGFloat = 22, animated: Bool = true) {
        self.icon = icon
        self.size = size
        self.animated = animated
    }

    /// Paused while scrolled out of view, so off-screen icons cost nothing.
    @State private var isOnScreen = true
    /// Interface icons play when they appear, then come to rest on their last frame
    /// (each looping icon costs CPU every frame; a screen has several).
    @State private var resting = false
    static let playSeconds: Double = 6

    var body: some View {
        Group {
            if animated, let period = icon.motionPeriod {
                LoopClock(period: period, paused: !isOnScreen || resting, fps: 15) { t in art(t) }
            } else {
                art(0)
            }
        }
        .frame(width: size, height: size)
        .modifier(PIconOuterShadow(dark: colorScheme == .dark))
        .onScrollVisibilityChange(threshold: 0.01) { isOnScreen = $0 }
        .task {
            try? await Task.sleep(for: .seconds(Self.playSeconds))
            resting = true
        }
        .accessibilityHidden(true)
    }

    /// The canvas is a little larger than the icon so shadows and swinging parts
    /// aren't clipped; layout still sees `size`.
    private func art(_ t: Double) -> some View {
        let icon = icon
        let size = size
        let pad = size * 0.2
        return Canvas { ctx, _ in
            let brush = PIconBrush(ctx: ctx, unit: size / 24, origin: CGPoint(x: pad, y: pad), shadowUnit: size / 24)
            PIconArt.draw(icon, t: t, brush: brush)
        }
        .frame(width: size + pad * 2, height: size + pad * 2)
        .frame(width: size, height: size)
    }
}

/// The whole icon sits a little off the table (light), or catches a rim of lamp light (dark).
private struct PIconOuterShadow: ViewModifier {
    let dark: Bool
    func body(content: Content) -> some View {
        if dark {
            content
                .shadow(color: Color(red: 1, green: 0.91, blue: 0.77).opacity(0.25), radius: 0, x: -0.3, y: -0.5)
                .shadow(color: .black.opacity(0.6), radius: 0.8, x: 0.6, y: 1.2)
        } else {
            content.paperShadow(depth: 0.4)
        }
    }
}

// MARK: - Brush

/// Draws paper pieces given in a design space (24×24 for icons) into a Canvas.
/// Paths are transformed into points before drawing, so the shadow keeps its
/// lamp direction (down-right) even when a part rotates.
struct PIconBrush {
    let ctx: GraphicsContext
    /// Points per design unit.
    let unit: CGFloat
    /// Where design (0, 0) lands in the canvas.
    let origin: CGPoint
    /// Points per shadow unit (a lifted piece's shadow is ~0.3, 0.7 units long).
    let shadowUnit: CGFloat
    var shadowColor = Color(red: 30 / 255, green: 15 / 255, blue: 5 / 255).opacity(0.35)

    private var toCanvas: CGAffineTransform {
        CGAffineTransform(translationX: origin.x, y: origin.y).scaledBy(x: unit, y: unit)
    }

    private func place(_ path: Path, _ t: CGAffineTransform) -> Path {
        path.applying(t.concatenating(toCanvas))
    }

    /// A piece lying flat (no shadow of its own).
    func flat(_ path: Path, _ color: Color, _ t: CGAffineTransform = .identity, opacity: Double = 1) {
        if opacity < 1 {
            ctx.drawLayer { layer in
                layer.opacity = opacity
                layer.fill(place(path, t), with: .color(color))
            }
        } else {
            ctx.fill(place(path, t), with: .color(color))
        }
    }

    /// A piece glued on top of another, casting a small shadow. `depth` scales the shadow.
    func lift(_ path: Path, _ color: Color, _ t: CGAffineTransform = .identity, opacity: Double = 1, depth: CGFloat = 1) {
        let s = shadowUnit * depth
        let shadow = shadowColor
        ctx.drawLayer { layer in
            layer.opacity = opacity
            layer.addFilter(.shadow(color: shadow, radius: 0.4 * s, x: 0.3 * s, y: 0.7 * s))
            layer.fill(place(path, t), with: .color(color))
        }
    }

    /// A strip of paper cut along a line (stems, soil lines, lantern frames).
    func strip(_ path: Path, width: CGFloat, _ color: Color, _ t: CGAffineTransform = .identity, lifted: Bool = true, cap: CGLineCap = .butt) {
        let shape = path.strokedPath(StrokeStyle(lineWidth: width, lineCap: cap, lineJoin: .round))
        if lifted { lift(shape, color, t) } else { flat(shape, color, t) }
    }

    /// The same brush clipped to a design-space rectangle (a sun hidden below its horizon).
    func clipped(to rect: CGRect) -> PIconBrush {
        var c = ctx
        c.clip(to: Path(rect).applying(toCanvas))
        var b = PIconBrush(ctx: c, unit: unit, origin: origin, shadowUnit: shadowUnit)
        b.shadowColor = shadowColor
        return b
    }

    // MARK: Transforms (design space)

    static func rotate(_ degrees: Double, about o: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: o.x, y: o.y)
            .rotated(by: degrees * .pi / 180)
            .translatedBy(x: -o.x, y: -o.y)
    }

    static func scale(_ sx: CGFloat, _ sy: CGFloat, about o: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: o.x, y: o.y)
            .scaledBy(x: sx, y: sy)
            .translatedBy(x: -o.x, y: -o.y)
    }

    static func move(_ x: CGFloat, _ y: CGFloat) -> CGAffineTransform {
        CGAffineTransform(translationX: x, y: y)
    }

    // MARK: Shapes

    static func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
    }

    static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat = 0) -> Path {
        let r = CGRect(x: x, y: y, width: w, height: h)
        return radius > 0 ? Path(roundedRect: r, cornerRadius: radius) : Path(r)
    }

    /// A paper colour from a hex literal, e.g. `hex(0xE3B65A)`.
    static func hex(_ v: UInt32) -> Color {
        Color(red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255, blue: Double(v & 0xFF) / 255)
    }

    /// Mix two hex colours (0 = a, 1 = b).
    static func mix(_ a: UInt32, _ b: UInt32, _ f: Double) -> Color {
        func ch(_ v: UInt32, _ shift: UInt32) -> Double { Double((v >> shift) & 0xFF) / 255 }
        func lerp(_ shift: UInt32) -> Double { ch(a, shift) + (ch(b, shift) - ch(a, shift)) * f }
        return Color(red: lerp(16), green: lerp(8), blue: lerp(0))
    }
}

// MARK: - Idle motion helpers

enum PIconMotion {
    /// A CSS `alternate` animation: `from` → `to` → `from` over `period` ms with the strong
    /// ease-in-out. `phase` 0.25 starts at the midpoint, so a still frame sits upright.
    static func swing(_ t: Double, period: Double, from: Double, to: Double, phase: Double = 0) -> Double {
        let p = loop(t, period: period, phase: phase)
        let tri = p < 0.5 ? p * 2 : 2 - p * 2
        return from + (to - from) * easeInOut.value(at: tri)
    }

    /// Degrees of a steady turn (`period` ms per revolution).
    static func spin(_ t: Double, period: Double) -> Double {
        loop(t, period: period) * 360
    }
}

// MARK: - SVG path data

/// Parses SVG path data (M L H V C S Q A Z, absolute and relative) into a `Path`.
/// Results are cached: each piece of art is parsed once.
enum PIconSVG {
    private static let cache = Mutex<[String: Path]>([:])

    static func path(_ d: String) -> Path {
        if let hit = cache.withLock({ $0[d] }) { return hit }
        let p = parse(d)
        cache.withLock { $0[d] = p }
        return p
    }

    private static func parse(_ d: String) -> Path {
        let s = Array(d.utf8)
        var i = 0
        var path = Path()
        var cmd: UInt8 = 0
        var cur = CGPoint.zero
        var start = CGPoint.zero
        var lastCubic: CGPoint?

        func skip() {
            while i < s.count, s[i] == 32 || s[i] == 44 || s[i] == 9 || s[i] == 10 || s[i] == 13 { i += 1 }
        }
        func isCommand(_ c: UInt8) -> Bool {
            switch c {
            case 65...90, 97...122: c != 101 && c != 69   // letters except the exponent "e"
            default: false
            }
        }
        func number() -> CGFloat? {
            skip()
            guard i < s.count else { return nil }
            let begin = i
            if s[i] == 45 || s[i] == 43 { i += 1 }
            var dot = false, digits = false
            while i < s.count {
                let c = s[i]
                if c >= 48 && c <= 57 { digits = true; i += 1 }
                else if c == 46 && !dot { dot = true; i += 1 }
                else if (c == 101 || c == 69) && digits {
                    i += 1
                    if i < s.count, s[i] == 45 || s[i] == 43 { i += 1 }
                    dot = true
                } else { break }
            }
            guard digits, let v = Double(String(decoding: s[begin..<i], as: UTF8.self)) else { i = begin; return nil }
            return CGFloat(v)
        }

        while true {
            skip()
            guard i < s.count else { break }
            if isCommand(s[i]) {
                cmd = s[i]
                i += 1
                if cmd == 90 || cmd == 122 {     // Z z
                    path.closeSubpath()
                    cur = start
                    lastCubic = nil
                    continue
                }
            } else if cmd == 0 {
                break
            }
            let rel = cmd >= 97
            let base = rel ? cur : .zero
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: base.x + x, y: base.y + y) }
            var cubic: CGPoint?

            switch cmd | 0x20 {   // lowercase
            case 109:   // m
                guard let x = number(), let y = number() else { return path }
                cur = pt(x, y); start = cur
                path.move(to: cur)
                cmd = rel ? 108 : 76   // further pairs are line-tos
            case 108:   // l
                guard let x = number(), let y = number() else { return path }
                cur = pt(x, y)
                path.addLine(to: cur)
            case 104:   // h
                guard let x = number() else { return path }
                cur = CGPoint(x: (rel ? cur.x : 0) + x, y: cur.y)
                path.addLine(to: cur)
            case 118:   // v
                guard let y = number() else { return path }
                cur = CGPoint(x: cur.x, y: (rel ? cur.y : 0) + y)
                path.addLine(to: cur)
            case 99:    // c
                guard let x1 = number(), let y1 = number(), let x2 = number(), let y2 = number(),
                      let x = number(), let y = number() else { return path }
                let c2 = pt(x2, y2)
                cur = pt(x, y)
                path.addCurve(to: cur, control1: pt(x1, y1), control2: c2)
                cubic = c2
            case 115:   // s
                guard let x2 = number(), let y2 = number(), let x = number(), let y = number() else { return path }
                let c1 = lastCubic.map { CGPoint(x: cur.x * 2 - $0.x, y: cur.y * 2 - $0.y) } ?? cur
                let c2 = pt(x2, y2)
                cur = pt(x, y)
                path.addCurve(to: cur, control1: c1, control2: c2)
                cubic = c2
            case 113:   // q
                guard let x1 = number(), let y1 = number(), let x = number(), let y = number() else { return path }
                cur = pt(x, y)
                path.addQuadCurve(to: cur, control: pt(x1, y1))
            case 97:    // a
                guard let rx = number(), let ry = number(), let phi = number(), let large = number(),
                      let sweep = number(), let x = number(), let y = number() else { return path }
                let end = pt(x, y)
                addArc(&path, from: cur, to: end, rx: rx, ry: ry, phi: phi, large: large != 0, sweep: sweep != 0)
                cur = end
            default:
                return path
            }
            lastCubic = cubic
        }
        return path
    }

    /// SVG elliptical arc → cubic Béziers (SVG 1.1 implementation notes F.6.5).
    private static func addArc(_ path: inout Path, from p0: CGPoint, to p1: CGPoint,
                               rx rxIn: CGFloat, ry ryIn: CGFloat, phi phiDeg: CGFloat, large: Bool, sweep: Bool) {
        guard p0 != p1 else { return }
        var rx = abs(rxIn), ry = abs(ryIn)
        guard rx > 0, ry > 0 else { path.addLine(to: p1); return }
        let phi = phiDeg * .pi / 180
        let cosP = cos(phi), sinP = sin(phi)
        let dx2 = (p0.x - p1.x) / 2, dy2 = (p0.y - p1.y) / 2
        let x1p = cosP * dx2 + sinP * dy2
        let y1p = -sinP * dx2 + cosP * dy2
        let lambda = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry)
        if lambda > 1 { rx *= sqrt(lambda); ry *= sqrt(lambda) }
        let num = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p
        let den = rx * rx * y1p * y1p + ry * ry * x1p * x1p
        let coef = (large != sweep ? 1 : -1) * sqrt(max(0, num / den))
        let cxp = coef * rx * y1p / ry
        let cyp = -coef * ry * x1p / rx
        let cx = cosP * cxp - sinP * cyp + (p0.x + p1.x) / 2
        let cy = sinP * cxp + cosP * cyp + (p0.y + p1.y) / 2

        func angle(_ ux: CGFloat, _ uy: CGFloat, _ vx: CGFloat, _ vy: CGFloat) -> CGFloat {
            atan2(ux * vy - uy * vx, ux * vx + uy * vy)
        }
        let ux = (x1p - cxp) / rx, uy = (y1p - cyp) / ry
        let vx = (-x1p - cxp) / rx, vy = (-y1p - cyp) / ry
        let theta1 = angle(1, 0, ux, uy)
        var dTheta = angle(ux, uy, vx, vy)
        if !sweep && dTheta > 0 { dTheta -= 2 * .pi }
        if sweep && dTheta < 0 { dTheta += 2 * .pi }

        let n = max(1, Int(ceil(abs(dTheta) / (.pi / 2))))
        let delta = dTheta / CGFloat(n)
        let k = 4 / 3 * tan(delta / 4)
        func point(_ a: CGFloat) -> CGPoint {
            CGPoint(x: cx + rx * cos(a) * cosP - ry * sin(a) * sinP,
                    y: cy + rx * cos(a) * sinP + ry * sin(a) * cosP)
        }
        func tangent(_ a: CGFloat) -> CGPoint {
            CGPoint(x: -rx * sin(a) * cosP - ry * cos(a) * sinP,
                    y: -rx * sin(a) * sinP + ry * cos(a) * cosP)
        }
        for j in 0..<n {
            let a1 = theta1 + CGFloat(j) * delta, a2 = a1 + delta
            let e1 = point(a1), e2 = point(a2), d1 = tangent(a1), d2 = tangent(a2)
            path.addCurve(to: j == n - 1 ? p1 : e2,
                          control1: CGPoint(x: e1.x + k * d1.x, y: e1.y + k * d1.y),
                          control2: CGPoint(x: e2.x - k * d2.x, y: e2.y - k * d2.y))
        }
    }
}

// MARK: - The art

private enum PIconArt {
    typealias B = PIconBrush
    typealias M = PIconMotion

    // Paper colours
    static let mustard = B.hex(0xE3B65A)
    static let terracotta = B.hex(0xD2694B)
    static let green = B.hex(0x3E7350)
    static let sage = B.hex(0x5F9A6E)
    static let mint = B.hex(0x7FAE7A)
    static let cream = B.hex(0xFBF5E8)
    static let parchment = B.hex(0xF3E8D2)
    static let kraft = B.hex(0xB88B5E)
    static let brass = B.hex(0xC79A3A)
    static let ink = B.hex(0x2B2118)
    static let amber = B.hex(0xF2A93B)
    static let paleSun = B.hex(0xFFE08A)

    static func svg(_ d: String) -> Path { PIconSVG.path(d) }
    static let c12 = CGPoint(x: 12, y: 12)

    /// Thin triangular rays round a centre: inner radius `r0` (±`half` rad), tip at `r1`.
    static func rays(_ count: Int, step: Double, center: CGPoint, r0: CGFloat, r1: CGFloat, half: CGFloat) -> Path {
        var p = Path()
        for i in 0..<count {
            let a = CGFloat(Double(i) * step * .pi / 180)
            p.move(to: CGPoint(x: center.x + cos(a - half) * r0, y: center.y + sin(a - half) * r0))
            p.addLine(to: CGPoint(x: center.x + cos(a) * r1, y: center.y + sin(a) * r1))
            p.addLine(to: CGPoint(x: center.x + cos(a + half) * r0, y: center.y + sin(a + half) * r0))
            p.closeSubpath()
        }
        return p
    }

    /// Wedge rays for a sun on the horizon (fajr, sunrise).
    static func horizonRay(_ deg: Double, center: CGPoint, r: CGFloat, side: CGFloat, turn: CGFloat, length: CGFloat) -> Path {
        let a = CGFloat(deg * .pi / 180)
        var p = Path()
        let s = CGPoint(x: center.x + cos(a) * r, y: center.y + sin(a) * r)
        let m = CGPoint(x: s.x + cos(a + turn) * side, y: s.y + sin(a + turn) * side)
        p.move(to: s)
        p.addLine(to: m)
        p.addLine(to: CGPoint(x: m.x + cos(a) * length, y: m.y + sin(a) * length))
        p.closeSubpath()
        return p
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    static func draw(_ icon: PaperIcon, t: Double, brush b: B) {
        switch icon {
        case .house:
            b.flat(svg("M4.5 11h15v10h-15z"), cream)
            b.lift(svg("M12 2.5 22 11.5h-3L12 5.5 5 11.5H2z"), terracotta)
            b.lift(svg("M10 21v-5.5h4V21z"), green)
            b.lift(svg("M15.5 4h2.4v4l-2.4-2z"), kraft)

        case .book:
            let s = M.swing(t, period: 7_200, from: 1, to: 1.05)
            let g = B.scale(s, s, about: CGPoint(x: 12, y: 20))
            b.flat(svg("M2.5 5.5c3-.8 6.4-.6 9.5 1.2v13c-3.1-1.8-6.5-2-9.5-1.2z"), cream, g)
            b.flat(svg("M21.5 5.5c-3-.8-6.4-.6-9.5 1.2v13c3.1-1.8 6.5-2 9.5-1.2z"), parchment, g)
            b.lift(svg("M1.5 18.8c3.4-1 7.2-.6 10.5 1.4 3.3-2 7.1-2.4 10.5-1.4v1.6c-3.4-.9-7.2-.4-10.5 1.4-3.3-1.8-7.1-2.3-10.5-1.4z"), terracotta, g)
            b.lift(svg("M15 4.5h2.6v6.5l-1.3-1-1.3 1z"), mustard, g)

        case .bookmark:
            let g = B.rotate(M.swing(t, period: 6_800, from: -6, to: 5, phase: 0.25), about: CGPoint(x: 12, y: 2))
            b.flat(svg("M6 2.5h12v19l-6-4.4-6 4.4z"), terracotta, g)
            b.lift(svg("M8.5 5h7v2.2h-7z"), cream, g)

        case .compass:
            let needle = B.rotate(M.swing(t, period: 5_200, from: -14, to: 10, phase: 0.25), about: c12)
            b.flat(B.circle(12, 12, 10), green)
            b.lift(B.circle(12, 12, 7.6), cream)
            b.lift(svg("M15.8 8.2 13.2 13.2 8.2 15.8 10.8 10.8z"), terracotta, needle)
            b.lift(B.circle(12, 12, 1.4), brass)

        case .clock:
            b.flat(B.circle(12, 12, 10), green)
            b.lift(B.circle(12, 12, 7.6), cream)
            for a in [0.0, 90, 180, 270] {
                b.flat(B.rect(11.4, 5.2, 1.2, 1.8), kraft, B.rotate(a, about: c12))
            }
            b.lift(svg("M11.2 12V7h1.6v5z"), ink, B.rotate(M.spin(t, period: 72_000), about: c12))
            b.lift(svg("M12 11.2l3.6 2.2-.8 1.3L11.6 12.6z"), terracotta, B.rotate(M.spin(t, period: 6_000), about: c12))
            b.lift(B.circle(12, 12, 1.3), brass)

        case .gear:
            let g = B.rotate(M.spin(t, period: 14_000), about: c12)
            b.flat(svg("M10.3 2h3.4l.5 2.6 1.9.8 2.2-1.5 2.4 2.4-1.5 2.2.8 1.9 2.6.5v3.4l-2.6.5-.8 1.9 1.5 2.2-2.4 2.4-2.2-1.5-1.9.8-.5 2.6h-3.4l-.5-2.6-1.9-.8-2.2 1.5-2.4-2.4 1.5-2.2-.8-1.9-2.6-.5v-3.4l2.6-.5.8-1.9-1.5-2.2 2.4-2.4 2.2 1.5 1.9-.8z"), green, g)
            b.lift(B.circle(12, 12, 3.6), mustard, g)

        case .search:
            b.flat(B.circle(10, 10, 7), green)
            b.lift(B.circle(10, 10, 4.2), cream)
            b.lift(svg("M14.5 16.3l1.8-1.8 6 6-1.8 1.8z"), kraft)

        case .share:
            b.flat(svg("M5 9h4v2H7v8h10v-8h-2V9h4v12H5z"), kraft)
            b.lift(svg("M12 2l4 4h-2.8v8h-2.4V6H8z"), green)

        case .plus:
            b.flat(svg("M10 3h4v7h7v4h-7v7h-4v-7H3v-4h7z"), green)

        case .aa:
            b.flat(svg("M2 20 8 4h3l6 16h-3.2l-1.4-4H6.6L5.2 20zm5.6-7h3.8L9.5 7.6z"), green)
            b.lift(svg("M15 20l3-8h2.3l3 8h-2.4l-.6-1.8h-2.4l-.6 1.8zm3.5-3.6h1.4l-.7-2.2z"), mustard)

        case .fajr:
            // The sun rises from behind the sea: the sea is drawn over it.
            let g = B.move(0, M.swing(t, period: 8_400, from: -1, to: 3.2))
            for i in 0..<5 {
                b.lift(horizonRay(-160 + Double(i) * 35, center: CGPoint(x: 12, y: 15), r: 8, side: 1.3, turn: 1.4, length: 3), B.hex(0xD4926B), g)
            }
            b.lift(svg("M5.5 15a6.5 6.5 0 0 1 13 0z"), B.hex(0xE8B87A), g)
            b.flat(svg("M2 15h20v7H2z"), B.hex(0x3A5A7A))
            b.lift(svg("M2 17.5h20v1.6H2z"), B.hex(0x1A2744))

        case .sunrise:
            let g = B.move(0, M.swing(t, period: 8_400, from: -1, to: 3.2))
            for i in 0..<7 {
                b.flat(horizonRay(-180 + Double(i) * 30, center: CGPoint(x: 12, y: 16), r: 8.5, side: 1.2, turn: 1.5, length: 3), mustard, g)
            }
            b.lift(svg("M4.5 16a7.5 7.5 0 0 1 15 0z"), amber, g)
            b.lift(svg("M8 15.5a4 4 0 0 1 8 0z"), paleSun, g)
            b.lift(svg("M2 16h20v5.5H2z"), mint)

        case .dhuhr:
            let g = B.rotate(M.spin(t, period: 24_000), about: c12)
            b.flat(rays(10, step: 36, center: c12, r0: 6, r1: 11, half: 0.25), amber, g)
            b.lift(B.circle(12, 12, 6.2), B.hex(0xF7B733), g)
            b.lift(B.circle(11.4, 11.4, 4), paleSun, g)

        case .sun:
            let g = B.rotate(M.spin(t, period: 24_000), about: c12)
            b.flat(rays(8, step: 45, center: c12, r0: 5.5, r1: 10.5, half: 0.3), amber, g)
            b.lift(B.circle(12, 12, 5.6), B.hex(0xFFD36B), g)

        case .asr:
            // The sun turns slowly while its cloud drifts across.
            let center = CGPoint(x: 10, y: 9)
            let g = B.rotate(M.spin(t, period: 30_000), about: center)
            b.flat(rays(9, step: 40, center: center, r0: 5, r1: 9, half: 0.28), mustard, g)
            b.lift(B.circle(10, 9, 5), amber, g)
            let cloud = B.move(M.swing(t, period: 11_000, from: -1.6, to: 1.8), 0)
            b.lift(svg("M7 21a3.4 3.4 0 0 1 .6-6.7 4.6 4.6 0 0 1 8.8-.9A3.8 3.8 0 0 1 18.5 21z"), cream, cloud)

        case .maghrib:
            // The sun sinks behind the horizon bands; clipped so it never shows below them.
            let g = B.move(0, M.swing(t, period: 9_200, from: -1.5, to: 2.6))
            let sky = b.clipped(to: CGRect(x: -4, y: -4, width: 32, height: 23))
            sky.lift(svg("M5 17a7 7 0 0 1 14 0z"), terracotta, g)
            sky.lift(svg("M8.2 17a3.8 3.8 0 0 1 7.6 0z"), B.hex(0xF0C88A), g)
            b.lift(svg("M2 17h20v2H2z"), B.hex(0x8B2E1A))
            b.lift(svg("M4 20h16v1.6H4z"), B.hex(0x2A1A3A))

        case .isha:
            let g = B.rotate(M.swing(t, period: 10_000, from: -6, to: 5, phase: 0.25), about: CGPoint(x: 15, y: 3))
            b.flat(svg("M14.5 2.5a9.5 9.5 0 1 0 7 15.6A8 8 0 0 1 14.5 2.5z"), B.hex(0xF6EBC8), g)
            b.lift(svg("M18 3.5l.9 1.9 2 .3-1.5 1.4.4 2-1.8-1-1.8 1 .4-2-1.5-1.4 2-.3z"), mustard, g)
            b.lift(B.circle(7, 12, 1.3), mustard, g)
            b.lift(B.circle(10, 17, 0.9), B.hex(0x1E2442), g, opacity: 0.25)

        case .moon:
            let g = B.rotate(M.swing(t, period: 10_000, from: -6, to: 5, phase: 0.25), about: CGPoint(x: 15, y: 3))
            b.flat(svg("M15 3a9 9 0 1 0 6.5 14.6A7.5 7.5 0 0 1 15 3z"), mustard, g)
            b.lift(B.circle(9, 12, 1.6), kraft, g, opacity: 0.6)

        case .star:
            // Rests, then a quick twinkle (shrink and twist) once per loop.
            let s = track(t, [Key(0, 1), Key(2_720, 1), Key(2_992, 0.82, out: true), Key(3_400, 1, out: true)])
            let r = track(t, [Key(0, 0), Key(2_720, 0), Key(2_992, -8, out: true), Key(3_400, 0, out: true)])
            let g = B.scale(s, s, about: c12).concatenating(B.rotate(r, about: c12))
            b.flat(svg("M12 2.5l2.8 5.9 6.4.8-4.7 4.4 1.2 6.4L12 16.9 6.3 20l1.2-6.4L2.8 9.2l6.4-.8z"), mustard, g)

        case .sprout:
            let grow = B.rotate(M.swing(t, period: 7_200, from: -4, to: 4, phase: 0.25), about: CGPoint(x: 12, y: 14.5))
            let leafL = B.rotate(M.swing(t, period: 4_800, from: 4, to: -6, phase: 0.25), about: CGPoint(x: 11.8, y: 10.6)).concatenating(grow)
            let leafR = B.rotate(M.swing(t, period: 5_760, from: -5, to: 5, phase: 0.25), about: CGPoint(x: 12.1, y: 8.6)).concatenating(grow)
            let budS = M.swing(t, period: 28_800 / 7, from: 1, to: 1.05)
            let bud = B.scale(budS, budS, about: CGPoint(x: 12, y: 6.3)).concatenating(grow)
            b.flat(svg("M6.5 15h11l-1.4 7H7.9z"), terracotta)
            b.lift(svg("M5.8 14h12.4v2.2H5.8z"), B.hex(0xB85A3E))
            b.strip(svg("M7.5 14.6h9"), width: 1.3, B.hex(0x6B4423))
            b.strip(svg("M12 14.5 C12 11 11.6 8 12 5"), width: 1.6, green, grow)
            b.lift(svg("M11.8 10.5 C8 10.6 6 8.4 6.2 6.6 C9 6.4 11.3 8 11.8 10.5Z"), sage, leafL)
            b.lift(svg("M12.1 8.2 C15.4 8.6 17.8 6.6 17.8 4.6 C14.8 4.4 12.6 5.8 12.1 8.2Z"), mint, leafR)
            b.lift(B.circle(12, 4.4, 1.9), B.hex(0xE6A08C), bud)

        case .beads:
            // The string steps round one bead at a time, as if counted.
            let steps: [Double] = [0, -12, -24, -12]
            let k = Int(t / 600) % 4
            let local = t - Double(Int(t / 600)) * 600
            let prev = steps[(k + 3) % 4]
            let angle = prev + (steps[k] - prev) * easeOut.value(at: min(1, local / 140))
            let g = B.rotate(angle, about: c12)
            var beads = Path()
            var marks = Path()
            for i in 0..<11 {
                let a = CGFloat(Double(i) / 11 * .pi * 1.6 + .pi * 0.7)
                let c = B.circle(12 + cos(a) * 7.5, 10 + sin(a) * 7.5, 1.9)
                if i % 5 == 0 { marks.addPath(c) } else { beads.addPath(c) }
            }
            b.flat(beads, kraft, g)
            b.flat(marks, green, g)
            b.lift(svg("M10.5 17.5h3l1 5h-5z"), green, g)

        case .pen:
            let o = CGPoint(x: 4, y: 20)
            let r = M.swing(t, period: 1_000, from: -4, to: 3, phase: 0.25)
            let x = M.swing(t, period: 1_000, from: -0.6, to: 0.8, phase: 0.25)
            let g = B.rotate(r, about: o).concatenating(B.move(x, 0))
            b.flat(svg("M4 20l1.2-4.6L16.5 4.1l3.4 3.4L8.6 18.8z"), mustard, g)
            b.lift(svg("M16.5 4.1l2-2 3.4 3.4-2 2z"), terracotta, g)
            b.lift(svg("M4 20l1.2-4.6 3.4 3.4z"), cream, g)

        case .bell:
            // Rings in a short burst, then rests. The clapper lags the bell a moment.
            let o = CGPoint(x: 12, y: 2)
            let g = B.rotate(ring(t), about: o)
            let clapper = B.rotate(ring(t - 70), about: o)
            b.flat(svg("M12 2.5c-3.9 0-6.5 3-6.5 6.7v4.3L3.5 17h17l-2-3.5V9.2c0-3.7-2.6-6.7-6.5-6.7z"), mustard, g)
            b.lift(svg("M9.3 18.5a2.7 2.7 0 0 0 5.4 0z"), kraft, clapper)
            b.lift(svg("M11 1h2v2.6h-2z"), kraft, g)

        case .lantern:
            let g = B.rotate(M.swing(t, period: 8_400, from: -6, to: 5, phase: 0.25), about: CGPoint(x: 12, y: 1.5))
            let glow = B.mix(0xFFD36B, 0xFFE9A8, M.swing(t, period: 2_800, from: 0, to: 1))
            let gold = B.hex(0xC98F22)
            b.flat(svg("M11 1.5h2v2.2h-2z"), kraft, g)
            b.lift(svg("M8 3.6h8l-1 2.4H9z"), gold, g)
            b.lift(svg("M8.6 6h6.8l1.6 10H7z"), gold, g)
            b.lift(svg("M9.6 7.2h4.8l1.2 7.6H8.4z"), glow, g)
            b.strip(svg("M12 7.2v7.6M9.6 11h4.8"), width: 0.9, gold, g)
            b.lift(svg("M7 16h10l-1.6 3.2H8.6z"), kraft, g)
            b.lift(svg("M11.2 19.2h1.6v2.4h-1.6z"), gold, g)

        case .masjid:
            b.flat(svg("M3 21v-8h18v8z"), green)
            b.lift(svg("M6.5 13c0-3.4 2.4-5.6 5.5-7 3.1 1.4 5.5 3.6 5.5 7z"), sage)
            b.lift(svg("M19.2 21V8.5h2.3V21z M19 8.6l1.35-3.4 1.35 3.4z"), kraft)
            b.lift(svg("M10.4 21v-4a1.6 1.6 0 0 1 3.2 0v4z"), mustard)
            b.lift(svg("M12 2.2a1.5 1.5 0 1 0 1 2.6 1.2 1.2 0 1 1-1-2.6z"), mustard)

        case .pin:
            // Hops, lands, squashes a little and settles (squash keeps its volume).
            let y = track(t, [Key(0, 0), Key(450, -2.4), Key(990, 0), Key(1_080, 0), Key(1_800, 0)])
            let sx = track(t, [Key(0, 1), Key(450, 0.97), Key(990, 1), Key(1_080, 1.05), Key(1_800, 1)])
            let sy = track(t, [Key(0, 1), Key(450, 1.04), Key(990, 1), Key(1_080, 0.94), Key(1_800, 1)])
            let g = B.scale(sx, sy, about: CGPoint(x: 12, y: 22.5)).concatenating(B.move(0, y))
            b.flat(svg("M12 1.5c-4.4 0-7.5 3.3-7.5 7.4 0 5.6 7.5 13.6 7.5 13.6s7.5-8 7.5-13.6c0-4.1-3.1-7.4-7.5-7.4z"), terracotta, g)
            b.lift(B.circle(12, 9, 3.2), cream, g)

        case .shield:
            b.flat(svg("M12 1.8 20.5 5v6.3c0 5.2-3.6 9.3-8.5 10.9-4.9-1.6-8.5-5.7-8.5-10.9V5z"), green)
            b.lift(svg("M12 4.6 18 7v4.4c0 3.7-2.5 6.7-6 8-3.5-1.3-6-4.3-6-8V7z"), cream)
            b.lift(svg("M10 11v-1.3a2 2 0 0 1 4 0V11h.8v4.4H9.2V11z"), kraft)

        case .widget:
            b.flat(B.rect(2, 2, 9, 9, radius: 2), mustard)
            b.lift(B.rect(13, 2, 9, 9, radius: 2), cream)
            b.lift(B.rect(2, 13, 20, 9, radius: 2), green)

        case .play:
            b.flat(svg("M7 4.5 19.5 12 7 19.5z"), green)
            b.lift(svg("M9 9l5 3-5 3z"), cream, opacity: 0.5)

        case .pause:
            b.flat(svg("M6 4.5h4.2v15H6z"), mustard)
            b.lift(svg("M13.8 4.5H18v15h-4.2z"), mustard)

        case .previous:
            b.flat(svg("M4 5h3v14H4z"), cream)
            b.lift(svg("M20 5v14L8 12z"), cream)

        case .next:
            b.flat(svg("M17 5h3v14h-3z"), cream)
            b.lift(svg("M4 5v14l12-7z"), cream)
        }
    }

    /// The bell's burst: still for 72% of the loop, then a decaying swing.
    static func ring(_ t: Double) -> Double {
        let p = 3_200.0
        let u = (t.truncatingRemainder(dividingBy: p) + p).truncatingRemainder(dividingBy: p)
        return track(u, [Key(0, 0), Key(2_304, 0), Key(2_432, 12), Key(2_560, -10), Key(2_688, 8),
                         Key(2_816, -5), Key(2_944, 2), Key(3_200, 0)])
    }
}

// MARK: - Previews

#Preview("Paper icons") {
    ScrollView {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 18) {
            ForEach(PaperIcon.allCases, id: \.self) { icon in
                VStack(spacing: 6) {
                    PaperIconView(icon, size: 40)
                    Text(icon.rawValue).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
    }
    .background(PIconBrush.hex(0xEADBC0))
}

#Preview("Paper icons, still") {
    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 12) {
        ForEach(PaperIcon.allCases, id: \.self) { icon in
            PaperIconView(icon, size: 24, animated: false)
        }
    }
    .padding(20)
    .background(Color(red: 0.12, green: 0.27, blue: 0.16))
}
