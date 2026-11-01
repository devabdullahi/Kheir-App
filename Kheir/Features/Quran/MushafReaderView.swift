import SwiftUI
import UIKit

/// Pages loaded so far, shared by every page on screen.
@Observable
@MainActor
final class MushafLibrary {
    static let shared = MushafLibrary()

    private(set) var pages: [Int: MushafPage] = [:]
    private(set) var failed: Set<Int> = []
    private let store: MushafStore

    init(store: MushafStore = .shared) {
        self.store = store
        _ = AppFonts.registered
    }

    func load(_ number: Int) async {
        guard (1...MushafPage.count).contains(number), pages[number] == nil else { return }
        failed.remove(number)
        do {
            pages[number] = try await store.page(number)
            await store.prefetch(around: number)
        } catch {
            failed.insert(number)
        }
    }
}

/// The mushaf reader: one page at a time on the desk, turned with a page curl
/// (right to left, as an Arabic book opens), with juz, page and hizb below.
struct MushafReaderView: View {
    @Binding var page: Int
    var library = MushafLibrary.shared
    @Environment(\.colorScheme) private var colorScheme
    /// While dragging along the strip: the page under the finger.
    @State private var scrubPage: Int?

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // The pages still to read, stacked under the open one.
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 0.89, green: 0.84, blue: 0.73))
                    .offset(x: -6, y: 5)
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(red: 0.94, green: 0.90, blue: 0.81))
                    .offset(x: -3, y: 2.5)
                MushafPageCurl(page: $page, library: library)
            }
            .paperShadow(depth: 1.5)
            .padding(.leading, 20)
            .padding(.trailing, 14)

            footer
                .padding(.horizontal, 20)
        }
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private var shown: Int { scrubPage ?? page }

    private var footer: some View {
        let info = library.pages[shown]
        return VStack(spacing: 10) {
            HStack {
                PaperTag(text: "Juz \(info?.juz ?? 1)", color: Color.adaptiveCardElevated(colorScheme), ink: Color.adaptiveSecondaryText(colorScheme), seed: 621)
                Spacer()
                Text("\(shown) of \(MushafPage.count)")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color.adaptiveText(colorScheme))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Spacer()
                PaperTag(text: "Hizb \(info?.hizb ?? 1)", color: Color.adaptiveCardElevated(colorScheme), ink: Color.adaptiveSecondaryText(colorScheme), seed: 622)
            }
            .opacity(info == nil && scrubPage == nil ? 0.6 : 1)
            progressStrip
        }
    }

    /// A paper strip that fills from the right as you read, with a brass brad
    /// for a knob. Drag along it to jump through the mushaf.
    private var progressStrip: some View {
        GeometryReader { geo in
            let fraction = CGFloat(shown - 1) / CGFloat(MushafPage.count - 1)
            let x = geo.size.width * (1 - fraction)
            ZStack(alignment: .trailing) {
                Capsule()
                    .fill(Color.paperKraft.opacity(0.45))
                    .frame(height: 6)
                Capsule()
                    .fill(Color.islamicGold)
                    .frame(width: max(6, geo.size.width - x), height: 6)
                BrassBrad(size: 16)
                    .position(x: x, y: geo.size.height / 2)
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let f = 1 - min(1, max(0, value.location.x / max(geo.size.width, 1)))
                        scrubPage = 1 + Int((f * CGFloat(MushafPage.count - 1)).rounded())
                    }
                    .onEnded { _ in
                        if let scrubPage { page = scrubPage }
                        scrubPage = nil
                    }
            )
        }
        .frame(height: 22)
        .accessibilityElement()
        .accessibilityLabel("Page")
        .accessibilityValue("\(page) of \(MushafPage.count)")
        .accessibilityAdjustableAction { direction in
            page = min(MushafPage.count, max(1, page + (direction == .increment ? 1 : -1)))
        }
    }
}

// MARK: - Page curl

/// `UIPageViewController` with a page curl, bound on the right like an Arabic book.
struct MushafPageCurl: UIViewControllerRepresentable {
    @Binding var page: Int
    let library: MushafLibrary

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        // Spine on the right: the next page lies under the left edge, which
        // lifts and folds over to the right.
        let controller = CurlController(
            transitionStyle: .pageCurl,
            navigationOrientation: .horizontal,
            options: [.spineLocation: NSNumber(value: UIPageViewController.SpineLocation.max.rawValue)]
        )
        controller.view.backgroundColor = .clear
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.setViewControllers([context.coordinator.host(page)], direction: .forward, animated: false)
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        guard let current = controller.viewControllers?.first as? PageHost,
              current.number != page,
              !context.coordinator.isTurning else { return }
        controller.setViewControllers(
            [context.coordinator.host(page)],
            direction: page > current.number ? .reverse : .forward,
            animated: !context.transaction.disablesAnimations
        )
    }

    /// Lets a swipe across the page turn it instead of going back. Going back
    /// still works from the screen's left edge.
    final class CurlController: UIPageViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard #available(iOS 26, *),
                  let pop = navigationController?.interactiveContentPopGestureRecognizer else { return }
            for turn in gestureRecognizers where turn is UIPanGestureRecognizer {
                pop.require(toFail: turn)
            }
        }
    }

    final class PageHost: UIHostingController<MushafPageSlot> {
        let number: Int

        init(number: Int, library: MushafLibrary) {
            self.number = number
            super.init(rootView: MushafPageSlot(number: number, library: library))
            safeAreaRegions = []
            view.backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: MushafPageCurl
        var isTurning = false

        init(_ parent: MushafPageCurl) { self.parent = parent }

        func host(_ number: Int) -> PageHost {
            PageHost(number: number, library: parent.library)
        }

        // With the spine on the right, UIKit's "before" lies under the left edge:
        // that is the next page of an Arabic book.
        func pageViewController(_ controller: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let current = viewController as? PageHost, current.number < MushafPage.count else { return nil }
            return host(current.number + 1)
        }

        func pageViewController(_ controller: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let current = viewController as? PageHost, current.number > 1 else { return nil }
            return host(current.number - 1)
        }

        func pageViewController(_ controller: UIPageViewController, willTransitionTo pending: [UIViewController]) {
            isTurning = true
        }

        func pageViewController(_ controller: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            isTurning = false
            if completed, let current = controller.viewControllers?.first as? PageHost {
                parent.page = current.number
            }
        }
    }
}

/// A page on screen: loads its layout and shows it when ready.
struct MushafPageSlot: View {
    let number: Int
    let library: MushafLibrary

    var body: some View {
        MushafPageView(
            number: number,
            page: library.pages[number],
            failed: library.failed.contains(number),
            onRetry: { Task { await library.load(number) } }
        )
        .task { await library.load(number) }
    }
}

/// Cards or Mushaf: two paper tabs in a shallow tray, the chosen one lifted out.
struct ReadingModeSwitch: View {
    @Binding var isMushaf: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            tab("Cards", selected: !isMushaf) { isMushaf = false }
            tab("Mushaf", selected: isMushaf) { isMushaf = true }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.adaptiveText(colorScheme).opacity(0.08))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Reading mode")
    }

    private func tab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : .open(0.25), action)
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(selected ? Color.adaptiveText(colorScheme) : Color.adaptiveSecondaryText(colorScheme))
                .frame(width: 96, height: 32)
                .background {
                    if selected {
                        Color.clear
                            .paperPiece(Color.adaptiveCardSurface(colorScheme), material: .card, depth: 0.7, radius: 10, seed: title.count, padding: nil)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
