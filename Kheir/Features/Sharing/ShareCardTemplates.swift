import SwiftUI

// MARK: - Paper collage share cards
//
// Share images are made from the same paper kit as the app, so an exported card
// looks like the screen it came from. Every card is laid out at a 360pt-wide
// design size and scaled up to the export size (1080 px wide), so cut edges,
// grain and shadows keep their hand-made proportions. Nothing animates: these
// are still images (`PaperIconView(animated: false)`).

/// Lays out `content` at a 360pt-wide design size and scales it to fill the frame.
private struct CollageCanvas<Content: View>: View {
    @ViewBuilder let content: (CGSize) -> Content

    var body: some View {
        GeometryReader { geo in
            let scale = geo.size.width / 360
            let design = CGSize(width: 360, height: geo.size.height / max(scale, 0.01))
            content(design)
                .frame(width: design.width, height: design.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
    }
}

private struct KheirWatermark: View {
    var ink: Color

    var body: some View {
        HStack(spacing: 4) {
            PaperIconView(.sprout, size: 13, animated: false)
            Text("Kheir")
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(ink.opacity(0.7))
        }
    }
}

/// The ayah or hadith itself: Arabic, meaning and a mustard reference tag.
private struct CollageText: View {
    let data: ShareCardData
    var ink: Color
    var arabicInk: Color? = nil
    var compact = false

    var body: some View {
        VStack(spacing: compact ? 10 : 14) {
            if let arabic = data.arabicText, !arabic.isEmpty {
                Text(arabic)
                    .font(.custom("ScheherazadeNew-Regular", size: arabicSize(arabic)))
                    .environment(\.layoutDirection, .rightToLeft)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(arabicInk ?? ink)
                    .lineSpacing(4)
                    .minimumScaleFactor(0.6)
            }
            Text(data.content)
                .font(.system(size: contentSize, design: .serif))
                .multilineTextAlignment(.center)
                .foregroundStyle(ink.opacity(0.92))
                .lineSpacing(3)
                .minimumScaleFactor(0.6)
            PaperTag(text: data.reference, color: .islamicGold, ink: .lightBodyText, seed: 191)
                .rotationEffect(.degrees(2))
        }
    }

    private func arabicSize(_ text: String) -> CGFloat {
        let base: CGFloat = compact ? 22 : 27
        return text.count > 160 ? base * 0.72 : text.count > 80 ? base * 0.85 : base
    }

    private var contentSize: CGFloat {
        let base: CGFloat = compact ? 13 : 15
        return data.content.count > 280 ? base * 0.82 : base
    }
}

/// A static strip of paper sky: torn bands, a paper sun and two clouds.
private struct PaperSkyStrip: View {
    var night = false

    var body: some View {
        Canvas { ctx, size in
            let bands: [Color] = night
                ? [Color(hex: "#1B2140"), Color(hex: "#24305A"), Color(hex: "#2E3C6E"), Color(hex: "#3A4778")]
                : [Color(hex: "#7EB4CE"), Color(hex: "#98C4D8"), Color(hex: "#B9D8E2"), Color(hex: "#F3D9A4")]
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bands[0]))
            for (i, color) in bands.enumerated().dropFirst() {
                let y = size.height * CGFloat(i) / CGFloat(bands.count)
                let edge = PaperNoise.tornLine(width: size.width + 10, y: y, amplitude: 4, seed: 200 + i)
                var p = Path()
                p.move(to: CGPoint(x: -10, y: size.height + 10))
                for pt in edge { p.addLine(to: pt) }
                p.addLine(to: CGPoint(x: size.width + 10, y: size.height + 10))
                p.closeSubpath()
                var layer = ctx
                layer.addFilter(.shadow(color: .black.opacity(0.18), radius: 1.5, x: 0, y: -1))
                layer.fill(p, with: .color(color))
            }
            // sun or moon
            let disc = CGRect(x: size.width * 0.68, y: size.height * 0.22, width: 34, height: 34)
            var lamp = ctx
            lamp.addFilter(.shadow(color: .black.opacity(0.25), radius: 1.5, x: 1, y: 2))
            lamp.fill(Path(ellipseIn: disc), with: .color(night ? Color(hex: "#F3E9D2") : Color.islamicGold))
            if night {
                lamp.fill(Path(ellipseIn: disc.offsetBy(dx: 9, dy: -5)), with: .color(bands[1]))
                for k in 0..<7 {
                    let x = seeded(k, salt: 3) * size.width, y = seeded(k, salt: 4) * size.height * 0.6
                    ctx.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.5, height: 2.5)), with: .color(.white.opacity(0.8)))
                }
            } else {
                for (k, c) in [(0.18, 0.30), (0.42, 0.52)].enumerated() {
                    let r = CGRect(x: size.width * c.0, y: size.height * c.1, width: 58, height: 18)
                    lamp.fill(Path(roundedRect: r, cornerRadius: 9), with: .color(.white.opacity(0.92)))
                    lamp.fill(Path(ellipseIn: CGRect(x: r.minX + 12 + CGFloat(k) * 6, y: r.minY - 9, width: 26, height: 22)), with: .color(.white.opacity(0.92)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Two torn hills along the bottom of a card.
private struct PaperHills: View {
    var body: some View {
        Canvas { ctx, size in
            for (i, color) in [Color(hex: "#7FAE7A"), Color(hex: "#5F9A6E"), Color(hex: "#3E7350")].enumerated() {
                let y = size.height * (0.25 + CGFloat(i) * 0.25)
                let edge = PaperNoise.tornLine(width: size.width + 10, y: y, amplitude: 9 - CGFloat(i) * 2, seed: 210 + i)
                var p = Path()
                p.move(to: CGPoint(x: -10, y: size.height + 10))
                for pt in edge { p.addLine(to: pt) }
                p.addLine(to: CGPoint(x: size.width + 10, y: size.height + 10))
                p.closeSubpath()
                var layer = ctx
                layer.addFilter(.shadow(color: .black.opacity(0.22), radius: 2, x: 0, y: -1.5))
                layer.fill(p, with: .color(color))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The table every card sits on.
private struct CollageTable: View {
    var color: Color
    var seed: Int

    var body: some View {
        ZStack {
            color
            PaperGrain(material: .construction, seed: seed)
            RadialGradient(colors: [Color(red: 1, green: 0.86, blue: 0.62).opacity(0.22), .clear], center: UnitPoint(x: 0.2, y: 0.08), startRadius: 10, endRadius: 520)
        }
    }
}

// MARK: - Minimal: cardstock taped to kraft

/// A cream cardstock sheet taped onto the kraft table.
struct MinimalShareCard: View {
    let data: ShareCardData
    let colorScheme: ColorScheme

    var body: some View {
        CollageCanvas { size in
            ZStack {
                CollageTable(color: .lightBackground, seed: 220)
                VStack(spacing: 16) {
                    Spacer(minLength: 0)
                    VStack(spacing: 14) {
                        PaperTag(text: data.type == .ayah ? "Daily Ayah" : "Daily Hadith", color: PaperInk.kraftLabel, ink: .lightBodyText, seed: 221)
                        CollageText(data: data, ink: .lightBodyText, compact: size.height < 500)
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .paperPiece(.lightCardSurface, material: .card, depth: 2.2, radius: 10, seed: 222, padding: 22)
                    .overlay(alignment: .top) { PaperTape(seed: 222).offset(y: -9) }
                    .rotationEffect(.degrees(-1))
                    Spacer(minLength: 0)
                    KheirWatermark(ink: .lightBodyText)
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 26)
            }
            .environment(\.colorScheme, .light)
        }
    }
}

// MARK: - Geometric: star cut-outs on terracotta

/// Terracotta construction paper with eight-point stars cut from mustard and
/// cream, and the text on a cream sheet pinned with brass brads.
struct GeometricShareCard: View {
    let data: ShareCardData
    let colorScheme: ColorScheme

    var body: some View {
        CollageCanvas { size in
            ZStack {
                CollageTable(color: .paperTerracotta, seed: 230)
                ForEach(0..<9, id: \.self) { i in
                    EightPointStar()
                        .fill(i.isMultiple(of: 2) ? Color.islamicGold : Color.lightCardSurface.opacity(0.9))
                        .frame(width: 26 + seeded(i, salt: 1) * 30, height: 26 + seeded(i, salt: 1) * 30)
                        .rotationEffect(.degrees(seeded(i, salt: 2) * 45))
                        .paperShadow(depth: 0.8)
                        .position(x: seeded(i, salt: 3) * size.width, y: seeded(i, salt: 4) * size.height)
                }
                VStack(spacing: 14) {
                    Spacer(minLength: 0)
                    VStack(spacing: 14) {
                        HStack {
                            BrassBrad(size: 9)
                            Spacer()
                            PaperTag(text: data.type == .ayah ? "Ayah" : "Hadith", color: .lightPrimary, ink: .lightCardSurface, seed: 231)
                            Spacer()
                            BrassBrad(size: 9)
                        }
                        CollageText(data: data, ink: .lightBodyText, compact: size.height < 500)
                    }
                    .frame(maxWidth: .infinity)
                    .paperPiece(.lightCardSurface, material: .card, depth: 2.4, radius: 16, seed: 232, padding: 20)
                    .rotationEffect(.degrees(0.8))
                    Spacer(minLength: 0)
                    KheirWatermark(ink: .lightCardSurface)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 26)
            }
            .environment(\.colorScheme, .light)
        }
    }
}

// MARK: - Calligraphy: night paper

/// Indigo night paper with a paper moon, the Arabic in mustard on a navy card.
struct CalligraphyShareCard: View {
    let data: ShareCardData
    let colorScheme: ColorScheme

    var body: some View {
        CollageCanvas { size in
            ZStack {
                CollageTable(color: .darkBackground, seed: 240)
                VStack(spacing: 0) {
                    PaperSkyStrip(night: true)
                        .frame(height: size.height * 0.22)
                        .clipShape(CutShape(cornerRadius: 10, edge: .torn, seed: 241))
                        .paperShadow(depth: 1.2)
                        .padding(14)
                    Spacer(minLength: 0)
                }
                VStack(spacing: 14) {
                    Spacer(minLength: size.height * 0.2)
                    VStack(spacing: 12) {
                        Text(data.type == .ayah ? "بِسْمِ اللَّهِ" : "حديث")
                            .font(.custom("ScheherazadeNew-Regular", size: 20))
                            .foregroundStyle(Color.islamicGold.opacity(0.85))
                        CollageText(data: data, ink: .darkBodyText, arabicInk: .islamicGold, compact: size.height < 500)
                    }
                    .frame(maxWidth: .infinity)
                    .paperPiece(.darkCardSurface, material: .construction, depth: 2.2, radius: 14, seed: 242, padding: 22)
                    .rotationEffect(.degrees(-0.8))
                    Spacer(minLength: 0)
                    KheirWatermark(ink: .darkBodyText)
                }
                .padding(.horizontal, 26)
                .padding(.vertical, 26)
            }
            .environment(\.colorScheme, .dark)
        }
    }
}

// MARK: - Nature: the garden card

/// A leaf-green card with a strip of paper sky on top and torn hills below,
/// the same scene as the app's header.
struct NatureShareCard: View {
    let data: ShareCardData
    let colorScheme: ColorScheme

    var body: some View {
        CollageCanvas { size in
            ZStack {
                CollageTable(color: .lightBackground, seed: 250)
                VStack(spacing: 0) {
                    PaperSkyStrip()
                        .frame(height: size.height * (size.height > 500 ? 0.3 : 0.28))
                    VStack(spacing: 14) {
                        CollageText(data: data, ink: .lightCardSurface, compact: size.height < 500)
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    PaperHills()
                        .frame(height: size.height * 0.12)
                }
                .background(Color.lightPrimary)
                .overlay(PaperGrain(material: .construction, seed: 251))
                .clipShape(CutShape(cornerRadius: 18, seed: 252))
                .paperShadow(depth: 2.4)
                .rotationEffect(.degrees(-1))
                .padding(.horizontal, 20)
                .padding(.top, 22)
                .padding(.bottom, 44)

                VStack {
                    Spacer()
                    KheirWatermark(ink: .lightBodyText)
                        .padding(.bottom, 16)
                }
            }
            .environment(\.colorScheme, .light)
        }
    }
}
