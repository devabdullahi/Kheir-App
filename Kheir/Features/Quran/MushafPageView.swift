import SwiftUI
import UIKit

/// One printed mushaf page: a cream cardstock sheet with fifteen justified lines,
/// cut-paper surah banners and small paper rosettes for the ayah ends.
///
/// The page is always light paper, in dark mode too, like a real mushaf under a lamp.
struct MushafPageView: View {
    let number: Int
    let page: MushafPage?
    var failed = false
    var onRetry: () -> Void = {}

    private let ink = Color.lightBodyText
    private let leaf = Color.lightPrimary
    private let gold = Color.lightGoldAccent

    var body: some View {
        ZStack {
            sheet
            VStack(spacing: 0) {
                header
                    .frame(height: 28)
                Rectangle()
                    .fill(gold.opacity(0.4))
                    .frame(height: 0.75)
                    .padding(.horizontal, 4)
                GeometryReader { geo in
                    if let page {
                        lines(page, in: geo.size)
                    } else {
                        placeholder
                            .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
                .padding(.vertical, 6)
                footer
                    .frame(height: 22)
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 10)
        }
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Page \(number) of \(MushafPage.count)")
    }

    // MARK: - Sheet

    private var sheet: some View {
        ZStack {
            Color.lightCardSurface
            PaperGrain(material: .card, seed: number)
            // An Arabic book binds on the right: the paper curves into the spine there.
            LinearGradient(colors: [.clear, Color(red: 0.42, green: 0.29, blue: 0.13).opacity(0.10)],
                           startPoint: UnitPoint(x: 0.9, y: 0.5), endPoint: .trailing)
            LinearGradient(colors: [Color(red: 0.42, green: 0.29, blue: 0.13).opacity(0.04), .clear],
                           startPoint: .leading, endPoint: UnitPoint(x: 0.05, y: 0.5))
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(gold.opacity(0.38), lineWidth: 0.9)
                .padding(7)
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .strokeBorder(gold.opacity(0.16), lineWidth: 0.6)
                .padding(10)
        }
        .accessibilityHidden(true)
    }

    private var header: some View {
        HStack {
            Text(page.map { "Juz \($0.juz)" } ?? "")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.lightSecondaryTextColor)
            Spacer()
            Text(MushafIndex.arabicName(page?.surah ?? MushafIndex.surah(onPage: number)))
                .font(.custom(MushafStore.fontName, size: 15))
                .foregroundStyle(leaf)
        }
        .padding(.horizontal, 4)
        .accessibilityHidden(true)
    }

    private var footer: some View {
        Text("\(number)")
            .font(.system(size: 10.5, weight: .heavy, design: .rounded))
            .foregroundStyle(leaf)
            .padding(.horizontal, 10)
            .padding(.vertical, 1.5)
            .background(Capsule().fill(Color.lightCardSurface))
            .overlay(Capsule().strokeBorder(gold.opacity(0.8), lineWidth: 0.8))
            .frame(maxHeight: .infinity, alignment: .bottom)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var placeholder: some View {
        if failed {
            VStack(spacing: 12) {
                Text("This page needs a connection the first time it opens.")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.lightSecondaryTextColor)
                    .multilineTextAlignment(.center)
                Button(action: onRetry) {
                    Text("Try again")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.lightCardSurface)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .paperPiece(.lightPrimary, material: .construction, depth: 0.8, radius: 10, seed: 610, padding: nil)
                }
                .buttonStyle(PaperPressStyle())
            }
            .padding(.horizontal, 30)
        } else {
            ProgressView()
                .tint(leaf)
                .accessibilityLabel("Loading page \(number)")
        }
    }

    // MARK: - Lines

    @ViewBuilder
    private func lines(_ page: MushafPage, in size: CGSize) -> some View {
        if page.number <= 2 {
            openingPage(page, in: size)
        } else {
            let rowHeight = size.height / 15
            let fontSize = MushafTypesetter.fontSize(page.lines, width: size.width, rowHeight: rowHeight)
            VStack(spacing: 0) {
                ForEach(page.lines) { line in
                    lineView(line, fontSize: fontSize, width: size.width, centered: false)
                        .frame(width: size.width, height: rowHeight)
                }
            }
        }
    }

    /// Al-Fatihah and the start of al-Baqarah: a few centred lines inside an arch.
    private func openingPage(_ page: MushafPage, in size: CGSize) -> some View {
        let archWidth = size.width * 0.88
        let textWidth = archWidth * 0.8
        let rowHeight = min(size.height / 13, 44)
        let fontSize = MushafTypesetter.fontSize(page.lines.filter { $0.kind == .text }, width: textWidth, rowHeight: rowHeight, gapScale: 0.3)
        return ZStack {
            MushafArch()
                .stroke(leaf.opacity(0.55), lineWidth: 1.4)
            MushafArch()
                .inset(by: 5)
                .stroke(gold.opacity(0.6), lineWidth: 0.9)
            VStack(spacing: 0) {
                ForEach(page.lines) { line in
                    lineView(line, fontSize: fontSize, width: line.kind == .banner ? archWidth - 12 : textWidth, centered: true)
                        .frame(height: rowHeight * 1.1)
                }
            }
            .padding(.top, size.height * 0.08)
        }
        .frame(width: archWidth, height: size.height * 0.94)
        .frame(width: size.width, height: size.height)
    }

    @ViewBuilder
    private func lineView(_ line: MushafLine, fontSize: CGFloat, width: CGFloat, centered: Bool) -> some View {
        switch line.kind {
        case .text:
            let gap = fontSize * 0.2
            let isShort = centered || MushafTypesetter.natural(line, fontSize: fontSize, gap: gap) < width * 0.35
            HStack(spacing: isShort ? gap : 0) {
                ForEach(Array(line.words.enumerated()), id: \.offset) { index, word in
                    if index > 0 && !isShort { Spacer(minLength: gap * 0.6) }
                    wordView(word, fontSize: fontSize)
                }
            }
            .frame(width: width)
            .environment(\.layoutDirection, .rightToLeft)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(line.words.filter { !$0.isAyahEnd }.map(\.text).joined(separator: " ")))

        case .banner:
            MushafBanner(surah: line.surah, fontSize: fontSize)
                .frame(width: width)

        case .bismillah:
            Text("بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ")
                .font(.custom(MushafStore.fontName, size: fontSize))
                .foregroundStyle(ink)
                .fixedSize()
                .accessibilityLabel("Bismillah")

        case .blank:
            Color.clear
        }
    }

    @ViewBuilder
    private func wordView(_ word: MushafWord, fontSize: CGFloat) -> some View {
        if word.isAyahEnd {
            AyahRosette(number: word.text, size: fontSize * MushafTypesetter.markerScale)
                .accessibilityLabel("End of ayah \(word.ayah)")
        } else {
            Text(word.text)
                .font(.custom(MushafStore.fontName, size: fontSize))
                .foregroundStyle(ink)
                .fixedSize()
        }
    }
}

// MARK: - Typesetting

/// Sizes the type so the longest line of a page fits its width, the way a mushaf
/// is set: every page shares one size, and each line is justified to the edges.
enum MushafTypesetter {
    static let markerScale: CGFloat = 1.05

    static func fontSize(_ lines: [MushafLine], width: CGFloat, rowHeight: CGFloat, gapScale: CGFloat = 0.2) -> CGFloat {
        let base = min(rowHeight * 0.62, 30)
        let widest = lines.filter { $0.kind == .text }
            .map { natural($0, fontSize: base, gap: base * gapScale) }
            .max() ?? 0
        guard widest > 0 else { return base }
        return min(base, base * width / widest)
    }

    /// The line's width with words set at `gap` apart.
    static func natural(_ line: MushafLine, fontSize: CGFloat, gap: CGFloat) -> CGFloat {
        let font = UIFont(name: MushafStore.fontName, size: fontSize) ?? .systemFont(ofSize: fontSize)
        let words = line.words.reduce(CGFloat(0)) { total, word in
            total + (word.isAyahEnd
                ? fontSize * markerScale
                : (word.text as NSString).size(withAttributes: [.font: font]).width)
        }
        return words + gap * CGFloat(max(0, line.words.count - 1))
    }
}

// MARK: - Ornaments

/// The ayah-end marker: a small cut-paper rosette with the ayah number.
struct AyahRosette: View {
    let number: String
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.lightCardSurface)
            Circle().strokeBorder(Color.lightGoldAccent, lineWidth: max(0.8, size * 0.06))
            Circle()
                .inset(by: size * 0.17)
                .stroke(Color.lightGoldAccent.opacity(0.4), lineWidth: 0.6)
            Text(number)
                .font(.custom(MushafStore.fontName, size: size * 0.44))
                .foregroundStyle(Color.lightPrimary)
                .fixedSize()
        }
        .frame(width: size, height: size)
        .shadow(color: Color(red: 0.3, green: 0.2, blue: 0.08).opacity(0.18), radius: 0.5, y: 0.6)
    }
}

/// A surah's opening: a strip of leaf-green paper with gold rosettes at the ends
/// and a cream label carrying the surah's name.
struct MushafBanner: View {
    let surah: Int
    let fontSize: CGFloat

    var body: some View {
        ZStack {
            BannerBand()
                .fill(Color.lightPrimary)
                .overlay(BannerBand().stroke(Color.lightGoldAccent.opacity(0.55), lineWidth: 0.8))
                .frame(height: fontSize * 1.05)
                .shadow(color: Color(red: 0.25, green: 0.16, blue: 0.05).opacity(0.25), radius: 0.6, y: 0.9)
            HStack {
                AyahRosette(number: "", size: fontSize * 0.62)
                Spacer()
                AyahRosette(number: "", size: fontSize * 0.62)
            }
            .padding(.horizontal, fontSize * 0.45)
            Text("سورة \(MushafIndex.arabicName(surah))")
                .font(.custom(MushafStore.fontName, size: fontSize * 0.78))
                .foregroundStyle(Color.lightPrimary)
                .fixedSize()
                .padding(.horizontal, fontSize * 1.1)
                .frame(height: fontSize * 1.35)
                .background(LabelTag().fill(Color.lightCardSurface))
                .overlay(LabelTag().stroke(Color.lightGoldAccent, lineWidth: 1))
                .shadow(color: Color(red: 0.25, green: 0.16, blue: 0.05).opacity(0.18), radius: 1, y: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Surah \(MushafIndex.name(surah))")
    }
}

/// A band with stepped, notched ends, like a strip cut with a craft punch.
private struct BannerBand: Shape {
    func path(in r: CGRect) -> Path {
        let n = min(r.height * 0.5, 14)
        let s = r.height * 0.18
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.minX + n * 0.6, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.minX + n, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - n, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - n * 0.6, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.maxX, y: r.minY + s))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.maxX - n * 0.6, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.maxX - n, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + n, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + n * 0.6, y: r.maxY - s))
        p.addLine(to: CGPoint(x: r.minX, y: r.maxY - s))
        p.closeSubpath()
        return p
    }
}

/// A label with pointed ends.
private struct LabelTag: Shape {
    func path(in r: CGRect) -> Path {
        let point = r.height * 0.42
        var p = Path()
        p.move(to: CGPoint(x: r.minX + point, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX - point, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.midY))
        p.addLine(to: CGPoint(x: r.maxX - point, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + point, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX, y: r.midY))
        p.closeSubpath()
        return p
    }
}

/// The arched frame around the opening pages.
private struct MushafArch: InsettableShape {
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let shoulder = r.minY + r.width * 0.22
        let corner: CGFloat = 10
        var p = Path()
        p.move(to: CGPoint(x: r.minX, y: r.maxY - corner))
        p.addLine(to: CGPoint(x: r.minX, y: shoulder))
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: CGPoint(x: r.minX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: shoulder), control: CGPoint(x: r.maxX, y: r.minY))
        p.addLine(to: CGPoint(x: r.maxX, y: r.maxY - corner))
        p.addQuadCurve(to: CGPoint(x: r.maxX - corner, y: r.maxY), control: CGPoint(x: r.maxX, y: r.maxY))
        p.addLine(to: CGPoint(x: r.minX + corner, y: r.maxY))
        p.addQuadCurve(to: CGPoint(x: r.minX, y: r.maxY - corner), control: CGPoint(x: r.minX, y: r.maxY))
        p.closeSubpath()
        return p
    }

    func inset(by amount: CGFloat) -> MushafArch {
        var arch = self
        arch.insetAmount += amount
        return arch
    }
}
