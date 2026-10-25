import SwiftUI

// MARK: - OnboardingView
//
// Onboarding is a book. Page 0 is its kraft cover; tapping it swings the cover
// open from the spine and the first page grows to fill the screen. Pages 1–18
// change with an eraser that rubs the page out and a pencil that writes the next
// one in. Every answer is written to `AppSettings` as it is made.
//
// One clock (a TimelineView, paused when nothing moves) draws both the book and
// the page turns, so every frame is a pure function of time.
//
// DEBUG launch arguments for screenshots:
//   -onboardingPage N   open the book on page N (0 = cover)
//   -onboardingFreeze MS freeze the book opening (with page 0) or a turn into page N at MS

struct OnboardingView: View {
    @State private var flow = OnboardingFlow()
    @State private var setup = OnboardingSetup()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let screen = CGSize(
                width: geo.size.width + insets.leading + insets.trailing,
                height: geo.size.height + insets.top + insets.bottom
            )
            TimelineView(.animation(minimumInterval: nil, paused: !flow.isAnimating)) { context in
                OnboardingStage(flow: flow, now: context.date, screen: screen, insets: insets)
            }
        }
        .environment(flow)
        .environment(setup)
        .environment(\.colorScheme, .light)
        .fontDesign(.rounded)
        .onAppear {
            flow.reduceMotion = reduceMotion
            applyDebugArguments()
        }
        .onChange(of: reduceMotion) { _, now in flow.reduceMotion = now }
    }

    private func applyDebugArguments() {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        func value(_ name: String) -> Double? {
            guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
            return Double(args[i + 1])
        }
        let page = value("-onboardingPage").map { min(OnboardingFlow.lastPage, max(0, Int($0))) }
        let freeze = value("-onboardingFreeze")
        guard page != nil || freeze != nil else { return }
        flow.frozenMs = freeze
        let target = page ?? 0
        if target == 0 {
            if let freeze {
                flow.page = 1
                flow.book = .opening(Date().addingTimeInterval(-freeze / 1000))
            }
        } else if let freeze, target > 1 {
            flow.book = .open
            flow.page = target
            flow.turn = .init(from: target - 1, to: target, dir: 1, start: Date().addingTimeInterval(-freeze / 1000))
        } else {
            flow.book = .open
            flow.page = target
        }
        #endif
    }
}

// MARK: - Stage

/// One frame of onboarding at time `now`.
private struct OnboardingStage: View {
    let flow: OnboardingFlow
    let now: Date
    let screen: CGSize
    let insets: EdgeInsets

    var body: some View {
        let k = bookProgress
        let beats = BookBeats(k: k ?? Self.openK)
        let bookRect = BookLayout.rect(screen: screen, insets: insets)
        let turnT = turnTime

        ZStack {
            if k != nil {
                CoverTable()
                    .opacity(1 - beats.grow)
                bookLayer(bookRect) {
                    BookPageBlock()
                        .frame(width: 10, height: bookRect.height - 6)
                        .offset(x: bookRect.width - 4, y: 3)
                }
                .opacity(beats.bookOpacity)
            }

            if let shown = shownPage(turnT) {
                // The page is laid out on the whole screen with the safe area (keyboard
                // included) as padding, so it scales into the book as one sheet.
                OnboardingPageRouter(page: shown)
                    .id(shown)
                    .padding(insets)
                    .frame(width: screen.width, height: screen.height)
                    .background { OBPagePaper() }
                    .modifier(PageInBook(grow: k == nil ? 1 : beats.grow, bookRect: bookRect, screen: screen, insets: EdgeInsets()))
            }

            if let k {
                bookLayer(bookRect) {
                    BookPageShadow(beats: beats)
                        .frame(width: bookRect.width, height: bookRect.height)
                }
                .opacity(1 - beats.grow)
                bookLayer(bookRect) {
                    BookCover(beats: beats, size: bookRect.size) { flow.openBook() }
                        .frame(width: bookRect.width, height: bookRect.height)
                }
                .opacity(beats.bookOpacity)
                .allowsHitTesting(k == 0)
            }

            if let turn = flow.turn, let t = turnT, t < OnboardingFlow.turnMs {
                EraserOverlay(t: t, dir: turn.dir, seed: turn.to * 13)
                // Tapping during a turn jumps to its end.
                Color.clear
                    .contentShape(Rectangle())
                    .ignoresSafeArea()
                    .onTapGesture { flow.finishTurn() }
                    .accessibilityHidden(true)
            }
        }
        // The eraser rubs and the pencil scratches in time with the drawing.
        .onChange(of: turnT) { _, t in
            let running = flow.turn != nil && (t ?? .infinity) < OnboardingFlow.turnMs
            PaperSounds.shared.turn(t: running ? t : nil, eraseMs: OnboardingFlow.eraseMs, writeMs: OnboardingFlow.writeMs, rows: EraserPath.rows)
        }
        .onDisappear { PaperSounds.shared.silence() }
        // The stage is the whole screen; everything inside is placed in screen coordinates.
        .frame(width: screen.width, height: screen.height)
        .ignoresSafeArea()
    }

    static let openK = OnboardingFlow.bookMs

    /// ms along the book opening, or nil when the book is open and out of the way.
    private var bookProgress: Double? {
        switch flow.book {
        case .closed: return 0
        case .open: return nil
        case .opening(let start): return min(OnboardingFlow.bookMs, elapsed(since: start))
        case .closing(let start): return max(0, OnboardingFlow.bookMs - elapsed(since: start))
        }
    }

    private var turnTime: Double? {
        guard let turn = flow.turn else { return nil }
        return elapsed(since: turn.start)
    }

    private func elapsed(since start: Date) -> Double {
        #if DEBUG
        if let frozen = flow.frozenMs { return frozen }
        #endif
        return max(0, now.timeIntervalSince(start) * 1000)
    }

    private func shownPage(_ t: Double?) -> Int? {
        if flow.book == .closed { return nil }
        if let turn = flow.turn, let t, t < OnboardingFlow.eraseMs { return turn.from }
        return max(1, flow.page)
    }

    /// A layer positioned on the book, in screen coordinates.
    private func bookLayer<C: View>(_ rect: CGRect, @ViewBuilder _ content: () -> C) -> some View {
        content()
            .frame(width: rect.width, height: rect.height, alignment: .topLeading)
            .position(x: rect.midX, y: rect.midY)
    }
}

/// The first page lying inside the book, growing to fill the screen as `grow` goes 0 → 1.
private struct PageInBook: ViewModifier {
    let grow: Double
    let bookRect: CGRect
    let screen: CGSize
    let insets: EdgeInsets

    func body(content: Content) -> some View {
        if grow >= 1 {
            content
        } else {
            let g = CGFloat(grow)
            let s0x = bookRect.width / screen.width, s0y = bookRect.height / screen.height
            let sx = s0x + (1 - s0x) * g, sy = s0y + (1 - s0y) * g
            // The page's visible extent (safe area included) starts at the book's corner.
            let left = bookRect.minX * (1 - g)
            let top = bookRect.minY * (1 - g)
            content
                .clipShape(BleedRect(insets: insets, radius: 8 * (1 - g)))
                .scaleEffect(x: sx, y: sy, anchor: .topLeading)
                .offset(x: left - insets.leading + insets.leading * sx, y: top - insets.top + insets.top * sy)
                .allowsHitTesting(false)
        }
    }
}

/// The view's bounds grown by the safe area: the full sheet of paper.
private struct BleedRect: Shape {
    let insets: EdgeInsets
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        let r = CGRect(
            x: rect.minX - insets.leading, y: rect.minY - insets.top,
            width: rect.width + insets.leading + insets.trailing,
            height: rect.height + insets.top + insets.bottom
        )
        return Path(roundedRect: r, cornerRadius: radius)
    }
}

// MARK: - Router

struct OnboardingPageRouter: View {
    let page: Int

    var body: some View {
        switch page {
        case 1: NamePage()
        case 2: JourneyPage()
        case 3: IntentionsPage()
        case 4: ArabicPage()
        case 5: QuranGoalPage()
        case 6: ReciterPage()
        case 7: LocationPage()
        case 8: MethodPage()
        case 9: AsrPage()
        case 10: AthanPage()
        case 11: FajrPage()
        case 12: RoutinesPage()
        case 13: WeeklyPage()
        case 14: DuaNamesPage()
        case 15: PaperPage()
        case 16: WidgetsPage()
        case 17: AccountPage()
        default: SummaryPage()
        }
    }
}
