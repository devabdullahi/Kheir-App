import SwiftUI

// MARK: - Palette
//
// Once the book is open every page is warm cream paper with dark ink, whatever
// the app theme, so the pages use fixed colours (and a light colour scheme).

enum OBInk {
    static let paper = Color(hex: "#F4EBD8")
    static let ink = Color(hex: "#2B2118")
    static let ink2 = Color(hex: "#6E5E4A")
    static let card = Color(hex: "#FBF5E8")
    static let raised = Color(hex: "#F3E8D2")
    static let green = Color(hex: "#3E7350")
    static let gold = Color(hex: "#C98F22")
    static let mustard = Color(hex: "#E3B65A")
    static let terracotta = Color(hex: "#D2694B")
    static let rose = Color(hex: "#E6A08C")
    static let sky = Color(hex: "#7EB4CE")
    static let kraft = Color(hex: "#B88B5E")
    static let leaf = Color(hex: "#7FAE7A")
    static let night = Color(hex: "#2B3560")
    static let pageNumber = Color(hex: "#9C8A6E")
    static let cream = Color(hex: "#FBF5E8")
}

// MARK: - Entrance

/// A piece laid onto the page: it comes down from slightly above, a little bigger
/// and tilted (seeded), and settles. Pieces are placed one by one (70 ms apart).
struct OBEnterModifier: ViewModifier {
    let index: Int
    var tilt: Double = 0
    @State private var placed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let lifted = !placed && !reduceMotion
        let entryTilt = (seeded(index, salt: 31) - 0.5) * 4
        content
            .scaleEffect(lifted ? 1.035 : 1)
            .rotationEffect(.degrees(lifted ? tilt + entryTilt : tilt))
            .offset(x: lifted ? -3 : 0, y: lifted ? -12 : 0)
            .opacity(lifted ? 0 : 1)
            .onAppear {
                guard !reduceMotion else { placed = true; return }
                withAnimation(.open(0.55).delay(Double(index) * 0.07)) { placed = true }
            }
    }
}

extension View {
    /// Places this piece on the page as part of the page's entrance. `tilt` is its resting angle.
    func obEnter(_ index: Int, tilt: Double = 0) -> some View {
        modifier(OBEnterModifier(index: index, tilt: tilt))
    }
}

// MARK: - Page paper

/// The blank page: cream paper, the gutter shadow by the spine on the left, a
/// stack of page edges on the right and the lamp's warm pool top-left.
struct OBPagePaper: View {
    var body: some View {
        ZStack {
            OBInk.paper
            PaperGrain(material: .card, seed: 404)
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.27, green: 0.18, blue: 0.06).opacity(0.30), location: 0),
                    .init(color: Color(red: 0.27, green: 0.18, blue: 0.06).opacity(0.10), location: 0.04),
                    .init(color: .clear, location: 0.11)
                ],
                startPoint: .leading, endPoint: .trailing
            )
            LinearGradient(
                stops: [
                    .init(color: Color(red: 0.27, green: 0.18, blue: 0.06).opacity(0.10), location: 0),
                    .init(color: .clear, location: 0.06)
                ],
                startPoint: .trailing, endPoint: .leading
            )
            RadialGradient(
                colors: [Color(red: 1, green: 0.886, blue: 0.667).opacity(0.30), .clear],
                center: UnitPoint(x: 0.25, y: 0.08), startRadius: 0, endRadius: 420
            )
            GeometryReader { geo in
                OBPageEdges()
                    .frame(width: 6, height: max(0, geo.size.height - 70))
                    .position(x: geo.size.width - 3, y: 40 + (geo.size.height - 70) / 2)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The edges of the pages still to come, seen from the side.
struct OBPageEdges: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(hex: "#FBF6EA")))
            var x: CGFloat = 1
            while x < size.width {
                ctx.fill(Path(CGRect(x: x, y: 0, width: 1, height: size.height)), with: .color(Color(hex: "#D9CBAE")))
                x += 2
            }
        }
        .shadow(color: Color(red: 0.24, green: 0.16, blue: 0.04).opacity(0.15), radius: 1, x: -1)
    }
}

// MARK: - Torn progress strip

/// A strip torn from a sheet: the shape of the onboarding progress bar.
struct TornStripShape: Shape {
    func path(in r: CGRect) -> Path {
        let top: [(CGFloat, CGFloat)] = [(0, 0.2), (0.10, 0), (0.25, 0.15), (0.40, 0), (0.55, 0.18), (0.70, 0), (0.85, 0.14), (1, 0)]
        let bottom: [(CGFloat, CGFloat)] = [(0.99, 1), (0.80, 0.86), (0.60, 1), (0.40, 0.88), (0.20, 1), (0, 0.9)]
        var p = Path()
        for (i, pt) in (top + bottom).enumerated() {
            let q = CGPoint(x: r.minX + pt.0 * r.width, y: r.minY + pt.1 * r.height)
            if i == 0 { p.move(to: q) } else { p.addLine(to: q) }
        }
        p.closeSubpath()
        return p
    }
}

struct OBProgressStrip: View {
    let fraction: Double
    @State private var filled = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shown = (filled || reduceMotion) ? fraction : 0
        ZStack(alignment: .leading) {
            OBInk.ink.opacity(0.14)
            GeometryReader { geo in
                LinearGradient(colors: [OBInk.kraft, OBInk.green], startPoint: .leading, endPoint: .trailing)
                    .frame(width: geo.size.width * fraction)
                    .mask(alignment: .leading) {
                        Rectangle().frame(width: geo.size.width * shown)
                    }
            }
        }
        .frame(width: 120, height: 7)
        .clipShape(TornStripShape())
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.open(0.9).delay(0.2)) { filled = true }
        }
    }
}

// MARK: - Top bar

struct OBTopBar: View {
    let page: Int
    var showsSkip = true
    @Environment(OnboardingFlow.self) private var flow

    var body: some View {
        HStack {
            Button { flow.back() } label: {
                Text("‹ Back")
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
            }
            .accessibilityLabel(page == 1 ? "Back to the cover" : "Back")
            Spacer()
            OBProgressStrip(fraction: Double(page + 1) / Double(OnboardingFlow.lastPage + 1))
                .accessibilityElement()
                .accessibilityLabel("Page \(page) of \(OnboardingFlow.lastPage)")
            Spacer()
            Button { flow.next() } label: {
                Text("Skip")
                    .frame(minWidth: 44, minHeight: 44, alignment: .trailing)
            }
            .opacity(showsSkip ? 1 : 0)
            .disabled(!showsSkip)
            .accessibilityHidden(!showsSkip)
            .accessibilityLabel("Skip this page")
        }
        .font(.footnote.weight(.heavy))
        .foregroundStyle(OBInk.ink2)
        .buttonStyle(.plain)
    }
}

// MARK: - Page scaffold

/// A page of the book: top bar, scrolling content (Dynamic Type safe) and a footer.
struct OBPage<Content: View, Footer: View>: View {
    let number: Int
    var showsSkip = true
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        VStack(spacing: 0) {
            OBTopBar(page: number, showsSkip: showsSkip)
                .padding(.horizontal, 18)
                .obEnter(0)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 22)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
            VStack(spacing: 10) {
                footer
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 22)
        }
        .overlay(alignment: .bottom) {
            Text("— \(number) —")
                .font(.system(size: 12, weight: .bold, design: .serif).italic())
                .foregroundStyle(OBInk.pageNumber)
                .padding(.bottom, 2)
                .accessibilityHidden(true)
        }
        .foregroundStyle(OBInk.ink)
    }
}

// MARK: - Text

struct OBHeading: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(.title, design: .rounded, weight: .black))
            .foregroundStyle(OBInk.ink)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
    }
}

struct OBLead: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(OBInk.ink2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)
    }
}

struct OBOverline: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundStyle(OBInk.gold)
    }
}

// MARK: - Buttons

/// The main action: a strip of green paper, pressed flat when tapped. Still after its entrance.
struct OBButton<Label: View>: View {
    var seed: Int
    var color: Color = OBInk.green
    let action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) {
            label
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 24)
                .padding(.vertical, 13)
                .paperPiece(color, material: .construction, depth: 1.3, radius: 12, seed: seed, padding: nil)
                .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
    }
}

extension OBButton where Label == Text {
    init(_ title: String, seed: Int, color: Color = OBInk.green, action: @escaping () -> Void) {
        self.seed = seed
        self.color = color
        self.action = action
        self.label = Text(title)
    }
}

/// A quiet second choice: dotted-underlined text.
struct OBGhostButton: View {
    let title: String
    let action: () -> Void
    init(_ title: String, action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.heavy))
                .underline(pattern: .dot)
                .foregroundStyle(OBInk.ink2)
                .frame(maxWidth: .infinity, minHeight: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Choices

/// The green tick on a picked card.
struct OBTick: View {
    var size: CGFloat = 22
    var body: some View {
        Image(systemName: "checkmark")
            .font(.system(size: size * 0.5, weight: .black))
            .foregroundStyle(OBInk.cream)
            .frame(width: size, height: size)
            .background(Circle().fill(OBInk.green))
            .shadow(color: .black.opacity(0.25), radius: 0.8, x: 0.4, y: 0.8)
            .accessibilityHidden(true)
    }
}

/// A card to pick. Picked cards lift off the table (longer shadow), tilt a little and get a tick.
struct OBOptionCard<Leading: View>: View {
    let title: String
    var subtitle: String?
    let selected: Bool
    let seed: Int
    let k: Int
    let action: () -> Void
    @ViewBuilder var leading: Leading

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                leading
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.heavy))
                        .foregroundStyle(OBInk.ink)
                    if let subtitle {
                        Text(subtitle)
                            .font(.footnote)
                            .foregroundStyle(OBInk.ink2)
                    }
                }
                .multilineTextAlignment(.leading)
                Spacer(minLength: 30)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .paperPiece(selected ? OBInk.card : OBInk.raised, depth: selected ? 1.8 : 0.5, radius: 14, seed: seed, padding: nil)
            .overlay(alignment: .trailing) {
                if selected {
                    OBTick().padding(.trailing, 12).transition(.scale.combined(with: .opacity))
                }
            }
            .rotationEffect(.degrees(selected ? (seeded(k, salt: 2) - 0.5) * 2.4 : 0))
            .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
        .animation(.open(0.3), value: selected)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

extension OBOptionCard where Leading == AnyView {
    init(_ title: String, subtitle: String? = nil, icon: PaperIcon?, selected: Bool, seed: Int, k: Int, action: @escaping () -> Void) {
        self.title = title
        self.subtitle = subtitle
        self.selected = selected
        self.seed = seed
        self.k = k
        self.action = action
        self.leading = icon.map { AnyView(PaperIconView($0, size: 26)) } ?? AnyView(EmptyView())
    }
}

/// A torn paper tag. As a choice it lifts and takes colour when picked.
struct OBTag: View {
    let text: String
    var color: Color = OBInk.mustard
    var seed: Int = 0
    var tilt: Double = 0
    var depth: CGFloat = 0.6
    var uppercase = true

    var body: some View {
        Text(text)
            .font(.caption.weight(.heavy))
            .tracking(uppercase ? 1.1 : 0.2)
            .textCase(uppercase ? .uppercase : nil)
            .foregroundStyle(OBInk.ink)
            .lineLimit(1)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .paperPiece(color, material: .construction, depth: depth, edge: .torn, radius: 3, seed: seed, padding: nil)
            .rotationEffect(.degrees(tilt))
    }
}

struct OBChoiceTag: View {
    let text: String
    let selected: Bool
    var onColor: Color = OBInk.mustard
    let seed: Int
    let k: Int
    var salt: Double = 3
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            OBTag(
                text: text,
                color: selected ? onColor : OBInk.raised,
                seed: seed,
                tilt: (seeded(k, salt: salt) - 0.5) * 3,
                depth: selected ? 1.4 : 0.4,
                uppercase: false
            )
            .frame(minHeight: 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
        .animation(.open(0.25), value: selected)
        .accessibilityLabel(text)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

/// A simple flowing layout for rows of tags.
struct OBFlow: Layout {
    var spacing: CGFloat = 6
    var lineSpacing: CGFloat = 6
    var alignment: HorizontalAlignment = .leading

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = rows(width: width, subviews: subviews)
        let height = rows.reduce(0) { $0 + $1.height } + CGFloat(max(0, rows.count - 1)) * lineSpacing
        let maxRow = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? maxRow, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(width: bounds.width, subviews: subviews) {
            var x: CGFloat
            switch alignment {
            case .center: x = bounds.minX + (bounds.width - row.width) / 2
            case .trailing: x = bounds.maxX - row.width
            default: x = bounds.minX
            }
            for i in row.items {
                let s = subviews[i].sizeThatFits(.unspecified)
                subviews[i].place(at: CGPoint(x: x, y: y + (row.height - s.height) / 2), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func rows(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for i in subviews.indices {
            let s = subviews[i].sizeThatFits(.unspecified)
            let extra = rows[rows.count - 1].items.isEmpty ? s.width : s.width + spacing
            if rows[rows.count - 1].width + extra > width, !rows[rows.count - 1].items.isEmpty {
                rows.append(Row())
            }
            let add = rows[rows.count - 1].items.isEmpty ? s.width : s.width + spacing
            rows[rows.count - 1].items.append(i)
            rows[rows.count - 1].width += add
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, s.height)
        }
        return rows.filter { !$0.items.isEmpty }
    }
}

// MARK: - Toggle

/// A paper switch. On its page's entrance the knob flicks into place (300 ms + 90 ms each).
struct PaperToggleStyle: ToggleStyle {
    var index: Int = 0

    func makeBody(configuration: Configuration) -> some View {
        PaperToggleBody(configuration: configuration, index: index)
    }
}

private struct PaperToggleBody: View {
    let configuration: ToggleStyleConfiguration
    let index: Int
    @State private var flicked = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let isOn = configuration.isOn
        let knobOn = isOn && (flicked || reduceMotion)
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                configuration.label
                Spacer(minLength: 8)
                Capsule()
                    .fill(isOn ? OBInk.green : OBInk.ink2.opacity(0.4))
                    .overlay(Capsule().stroke(.black.opacity(0.18), lineWidth: 1).blur(radius: 0.6).offset(y: 0.6).clipShape(Capsule()))
                    .frame(width: 42, height: 24)
                    .overlay(alignment: knobOn ? .trailing : .leading) {
                        Circle()
                            .fill(OBInk.card)
                            .frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                            .padding(2)
                    }
                    .animation(.open(0.5), value: knobOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: configuration.$isOn) { configuration.label }
        }
        .onAppear {
            guard !reduceMotion else { flicked = true; return }
            withAnimation(.open(0.5).delay(0.3 + Double(index) * 0.09)) { flicked = true }
        }
    }
}

// MARK: - Live countdown

/// "1:24:10" until `target`, ticking every second.
struct OBCountdown: View {
    let target: Date
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            Text(Self.format(target.timeIntervalSince(ctx.date)))
                .monospacedDigit()
        }
    }

    static func format(_ interval: TimeInterval) -> String {
        let s = max(0, Int(interval))
        let h = s / 3600, m = (s % 3600) / 60, x = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, x) : String(format: "%d:%02d", m, x)
    }
}

extension Date {
    var obTime: String { formatted(date: .omitted, time: .shortened) }
}
