import SwiftUI

// MARK: - Eraser → pencil page change
//
// A paper eraser comes in from beyond the edge already moving and scrubs the page
// away row by row (zigzag, with a scrub wiggle); crumbs flick off and fall. The
// page is blank for an instant, then a pencil writes the next page in row by row
// with a slight hand wobble. Everything here is a pure function of `t` (ms since
// the turn began), read from one clock by the stage.

/// The zigzag the tools follow: rows from top to bottom (bottom to top going back).
struct EraserPath {
    static let rows = 7
    private var points: [CGPoint] = []
    private var lengths: [CGFloat] = []
    private(set) var total: CGFloat = 0
    let rowHeight: CGFloat

    init(size: CGSize, dir: Int) {
        rowHeight = size.height / CGFloat(Self.rows)
        var pts: [CGPoint] = []
        for r in 0..<Self.rows {
            let y = rowHeight * (CGFloat(r) + 0.5)
            let leftToRight = (r % 2 == 0) == (dir > 0)
            let l: CGFloat = -40, rr = size.width + 40
            pts.append(CGPoint(x: leftToRight ? l : rr, y: y))
            pts.append(CGPoint(x: leftToRight ? rr : l, y: y))
        }
        if dir < 0 { pts.reverse() }
        points = pts
        for k in 1..<pts.count {
            let len = hypot(pts[k].x - pts[k - 1].x, pts[k].y - pts[k - 1].y)
            lengths.append(len)
            total += len
        }
    }

    /// The point `d` along the path and the direction the tool is moving in x (+1 / -1).
    func point(at d: CGFloat) -> (CGPoint, CGFloat) {
        var rest = max(0, d)
        for k in 0..<lengths.count {
            if rest <= lengths[k] {
                let a = points[k], b = points[k + 1]
                let f = lengths[k] > 0 ? rest / lengths[k] : 0
                let sx: CGFloat = b.x > a.x ? 1 : (b.x < a.x ? -1 : 0)
                return (CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f), sx)
            }
            rest -= lengths[k]
        }
        return (points.last ?? .zero, 1)
    }

    /// The stroke from the start up to fraction `f`, sampled every `spacing` pt (stable
    /// samples, so the scribble doesn't shimmer from frame to frame) and jittered.
    func stroke(upTo f: Double, spacing: CGFloat = 14, jitter: (Int) -> CGVector) -> Path {
        let end = total * CGFloat(min(1, max(0, f)))
        var p = Path()
        var k = 0
        var d: CGFloat = 0
        while d < end {
            let (q, _) = point(at: d)
            let j = jitter(k)
            let pt = CGPoint(x: q.x + j.dx, y: q.y + j.dy)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
            k += 1
            d = CGFloat(k) * spacing
        }
        let (q, _) = point(at: end)
        if k == 0 { p.move(to: q) }
        p.addLine(to: q)
        return p
    }
}

/// The overlay drawn over the page during a turn.
struct EraserOverlay: View {
    let t: Double
    let dir: Int
    let seed: Int

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let path = EraserPath(size: size, dir: dir)
            ZStack {
                // Blank paper shows wherever the page has been rubbed out.
                OBPagePaper()
                    .mask {
                        Canvas { ctx, _ in
                            drawMask(ctx, size: size, path: path)
                        }
                    }
                Canvas { ctx, _ in
                    if t < OnboardingFlow.eraseMs {
                        drawCrumbs(ctx, path: path)
                        drawEraser(ctx, path: path)
                    } else {
                        drawGraphite(ctx, path: path)
                        drawPencil(ctx, path: path)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var eraseP: Double { easeInOut.value(at: min(1, t / OnboardingFlow.eraseMs)) }
    private var writeP: Double { easeInOut.value(at: min(1, max(0, t - OnboardingFlow.eraseMs) / OnboardingFlow.writeMs)) }

    private func drawMask(_ ctx: GraphicsContext, size: CGSize, path: EraserPath) {
        let style = StrokeStyle(lineWidth: path.rowHeight * 1.38, lineCap: .round, lineJoin: .round)
        if t < OnboardingFlow.eraseMs {
            let stroke = path.stroke(upTo: eraseP) { k in CGVector(dx: sin(Double(k) * 2.1) * 6, dy: 0) }
            ctx.stroke(stroke, with: .color(.black), style: style)
        } else {
            var c = ctx
            c.fill(Path(CGRect(origin: .zero, size: size).insetBy(dx: -60, dy: -60)), with: .color(.black))
            c.blendMode = .destinationOut
            let stroke = path.stroke(upTo: writeP) { k in CGVector(dx: 0, dy: sin(Double(k) * 1.7) * 3) }
            c.stroke(stroke, with: .color(.black), style: StrokeStyle(lineWidth: path.rowHeight * 1.42, lineCap: .round, lineJoin: .round))
        }
    }

    private func drawCrumbs(_ ctx: GraphicsContext, path: EraserPath) {
        let s = Double(seed)
        for c in 0..<26 {
            let ts = seeded(c, salt: s) * OnboardingFlow.eraseMs * 0.92
            guard t >= ts else { continue }
            let age = (t - ts) / 1000
            guard age <= 0.9 else { continue }
            let (q, _) = path.point(at: path.total * CGFloat(easeInOut.value(at: ts / OnboardingFlow.eraseMs)))
            let vx = (seeded(c, salt: s + 1) - 0.5) * 140
            let vy = -40 - seeded(c, salt: s + 2) * 60
            let x = q.x + vx * age
            let y = q.y + vy * age + 520 * age * age
            let r = 1.2 + seeded(c, salt: s + 3) * 1.8
            var g = ctx
            g.opacity = max(0, 1 - age / 0.9)
            g.translateBy(x: x, y: y)
            g.rotate(by: .radians(age * 8 * (seeded(c, salt: 9) - 0.5)))
            g.addFilter(.shadow(color: Color(red: 0.16, green: 0.08, blue: 0.02).opacity(0.3), radius: 1, y: 1))
            g.fill(Path(CGRect(x: -r * 1.2, y: -r * 0.7, width: r * 2.4, height: r * 1.4)), with: .color(c % 3 == 0 ? Color(hex: "#D9B9A0") : Color(hex: "#E98C8C")))
        }
    }

    private func toolShadow(_ ctx: inout GraphicsContext) {
        ctx.addFilter(.shadow(color: Color(red: 0.16, green: 0.08, blue: 0.02).opacity(0.35), radius: 4, x: 2, y: 5))
        ctx.addFilter(.shadow(color: Color(red: 0.16, green: 0.08, blue: 0.02).opacity(0.4), radius: 0.6, x: 0.6, y: 1.2))
    }

    private func drawEraser(_ ctx: GraphicsContext, path: EraserPath) {
        let (q, sx) = path.point(at: path.total * CGFloat(eraseP))
        let scrub = 7 * sin(t / 45)
        let tilt = (-18 + 6 * sin(t / 60)) * Double(sx == 0 ? 1 : sx)
        let squash = 0.03 * sin(t / 45)
        var c = ctx
        c.translateBy(x: q.x + scrub, y: q.y - 10)
        c.rotate(by: .degrees(tilt))
        c.scaleBy(x: 1.3 * (1 + squash), y: 1.3 * (1 - squash))
        toolShadow(&c)
        c.drawLayer { l in
            var rubber = Path()
            rubber.move(to: CGPoint(x: -40, y: -15))
            rubber.addQuadCurve(to: CGPoint(x: -36, y: -19), control: CGPoint(x: -41, y: -19))
            rubber.addLine(to: CGPoint(x: 8, y: -19))
            rubber.addLine(to: CGPoint(x: 8, y: 19))
            rubber.addLine(to: CGPoint(x: -36, y: 19))
            rubber.addQuadCurve(to: CGPoint(x: -40, y: 15), control: CGPoint(x: -41, y: 19))
            rubber.closeSubpath()
            l.fill(rubber, with: .color(Color(hex: "#E98C8C")))
            var shine = Path()
            shine.move(to: CGPoint(x: -40, y: -15))
            shine.addQuadCurve(to: CGPoint(x: -36, y: -19), control: CGPoint(x: -41, y: -19))
            shine.addLine(to: CGPoint(x: 8, y: -19))
            shine.addLine(to: CGPoint(x: 8, y: -12))
            shine.addLine(to: CGPoint(x: -40, y: -12))
            shine.closeSubpath()
            l.fill(shine, with: .color(Color(hex: "#F4ABA6")))
            l.fill(Path(roundedRect: CGRect(x: 4, y: -21, width: 38, height: 42), cornerRadii: RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: 3, topTrailing: 3)), with: .color(Color(hex: "#7EB4CE")))
            l.fill(Path(CGRect(x: 4, y: -21, width: 36, height: 7)), with: .color(Color(hex: "#9ACBE0")))
            l.draw(
                Text("KHEIR").font(.system(size: 10, weight: .black, design: .rounded)).foregroundStyle(Color(hex: "#1E2442")),
                at: CGPoint(x: 23, y: 2)
            )
        }
    }

    private func drawGraphite(_ ctx: GraphicsContext, path: EraserPath) {
        var p = Path()
        for k in 0..<8 {
            let (q, _) = path.point(at: path.total * CGFloat(max(0, writeP - Double(k) * 0.006)))
            let dy = sin(t / 30 + Double(k)) * 4
            let pt = CGPoint(x: q.x, y: q.y + dy)
            if k == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        ctx.stroke(p, with: .color(Color(red: 0.17, green: 0.13, blue: 0.09).opacity(0.45)), lineWidth: 1.1)
    }

    private func drawPencil(_ ctx: GraphicsContext, path: EraserPath) {
        let (q, _) = path.point(at: path.total * CGFloat(writeP))
        let wobble = 2.2 * sin(t / 38) + 1.2 * sin(t / 23)
        var c = ctx
        c.translateBy(x: q.x, y: q.y + wobble)
        c.rotate(by: .degrees(-32 + 3 * sin(t / 70)))
        c.scaleBy(x: 1.2, y: 1.2)
        toolShadow(&c)
        c.drawLayer { l in
            var lead = Path()
            lead.move(to: .zero)
            lead.addLine(to: CGPoint(x: 9, y: -3.2))
            lead.addLine(to: CGPoint(x: 9, y: 3.2))
            lead.closeSubpath()
            var wood = Path()
            wood.move(to: CGPoint(x: 9, y: -3.2))
            wood.addLine(to: CGPoint(x: 30, y: -11))
            wood.addLine(to: CGPoint(x: 30, y: 11))
            wood.addLine(to: CGPoint(x: 9, y: 3.2))
            wood.closeSubpath()
            l.fill(wood, with: .color(Color(hex: "#E8C49A")))
            l.fill(lead, with: .color(Color(hex: "#2B2118")))
            l.fill(Path(CGRect(x: 30, y: -11, width: 130, height: 22)), with: .color(Color(hex: "#E3B65A")))
            l.fill(Path(CGRect(x: 30, y: -11, width: 130, height: 7)), with: .color(Color(hex: "#F2CF78")))
            l.fill(Path(CGRect(x: 30, y: 4, width: 130, height: 7)), with: .color(Color(hex: "#C98F22")))
            l.fill(Path(CGRect(x: 160, y: -11, width: 14, height: 22)), with: .color(Color(hex: "#B9B4A8")))
            for x in [163.0, 168.0] {
                l.fill(Path(CGRect(x: x - 0.5, y: -11, width: 1, height: 22)), with: .color(Color(hex: "#8F8A80")))
            }
            l.fill(Path(roundedRect: CGRect(x: 174, y: -11, width: 22, height: 22), cornerRadii: RectangleCornerRadii(topLeading: 0, bottomLeading: 0, bottomTrailing: 6, topTrailing: 6)), with: .color(Color(hex: "#E98C8C")))
        }
    }
}
