import SwiftUI

// MARK: - OnboardingState

private enum OnboardingState: Equatable {
    case closed
    case open(page: Int)
}

// MARK: - Prayer Method

private enum PrayerMethod: String, CaseIterable, Identifiable {
    case isna        = "ISNA"
    case mwl         = "MWL"
    case ummAlQura   = "Umm Al-Qura"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .isna:      "Islamic Society of North America"
        case .mwl:       "Muslim World League"
        case .ummAlQura: "Saudi Arabia — Makkah"
        }
    }
}

// MARK: - OnboardingView

/// Root container for the book-style onboarding flow.
///
/// State machine:
///   `.closed`       → shows the leather `BookCoverView`
///   `.open(page:)`  → shows `OnboardingPageView` for page 1, 2, or 3
///
/// Navigation is driven by horizontal swipe gestures (drag) or the CTA button on page 3.
/// A "Skip" affordance is always visible once the book opens.
struct OnboardingView: View {
    // MARK: - Persistence

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    // MARK: - Reduce Motion

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var flowState: OnboardingState = .closed

    /// Cover open animation progress (0 = closed, 1 = open).
    @State private var coverOpenProgress: Double = 0

    /// Page flip drag progress for current page (0–1).
    @State private var flipProgress: Double = 0
    @State private var isFlipping: Bool = false

    // Page 1
    @State private var locationGranted: Bool = false

    // Page 2
    @State private var selectedMethod: PrayerMethod = .isna

    // Page 3
    @State private var prayerNotificationsOn: Bool = true
    @State private var dailyAyahOn: Bool = false

    // MARK: - Private constants

    private let totalPages = 3
    private let gold        = Color(red: 0.831, green: 0.659, blue: 0.278)
    private let creamText   = Color(red: 0.941, green: 0.910, blue: 0.855)
    private let inkDark     = Color(red: 0.102, green: 0.165, blue: 0.133)
    private let greenTop    = Color(red: 0.133, green: 0.341, blue: 0.235)
    private let greenBottom = Color(red: 0.102, green: 0.420, blue: 0.259)

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Dark background — always present
                Color(red: 0.039, green: 0.059, blue: 0.118)
                    .ignoresSafeArea()

                switch flowState {
                case .closed:
                    closedView(size: geo.size)
                        .transition(reduceMotion ? .opacity : .identity)

                case .open(let page):
                    openView(page: page, size: geo.size)
                        .transition(reduceMotion ? .opacity : .identity)
                }
            }
        }
    }

    // MARK: - Closed State

    private func closedView(size: CGSize) -> some View {
        ZStack {
            BookCoverView(onOpen: openBook)
                .frame(width: bookWidth(for: size), height: bookHeight(for: size))
                // Cover swings open around its leading edge
                .rotation3DEffect(
                    reduceMotion ? .zero : .degrees(coverOpenProgress * -160),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.4
                )
                .opacity(coverOpenProgress > 0.9 ? 0 : 1)
        }
    }

    // MARK: - Open State

    private func openView(page: Int, size: CGSize) -> some View {
        ZStack(alignment: .topTrailing) {
            // Page content
            pageContent(for: page, size: size)

            // Skip button
            skipButton
        }
    }

    private func pageContent(for page: Int, size: CGSize) -> some View {
        ZStack {
            // Previous page peeking from behind during flip
            if page > 1 {
                pageView(for: page - 1, size: size)
                    .zIndex(0)
            }

            // Current page
            pageView(for: page, size: size)
                .pageFlip(progress: flipProgress, isFlipping: isFlipping)
                .zIndex(1)
        }
        .frame(width: bookWidth(for: size), height: bookHeight(for: size))
        .gesture(pageDragGesture(page: page, size: size))
    }

    @ViewBuilder
    private func pageView(for page: Int, size: CGSize) -> some View {
        switch page {
        case 1:
            OnboardingPageView(chapterNumber: 1, pageNumber: page) {
                locationPageContent
            }
            .frame(width: bookWidth(for: size), height: bookHeight(for: size))

        case 2:
            OnboardingPageView(chapterNumber: 2, pageNumber: page) {
                prayerMethodPageContent
            }
            .frame(width: bookWidth(for: size), height: bookHeight(for: size))

        case 3:
            OnboardingPageView(chapterNumber: 3, pageNumber: page) {
                notificationsPageContent
            }
            .frame(width: bookWidth(for: size), height: bookHeight(for: size))

        default:
            EmptyView()
        }
    }

    // MARK: - Page 1 — Location

    private var locationPageContent: some View {
        VStack(spacing: 0) {
            Image(systemName: "location.circle.fill")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(greenTop)
                .padding(.bottom, 20)

            Text("Your Location")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(inkDark)
                .padding(.bottom, 10)

            Text("For accurate prayer times\nand Qibla direction.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(inkDark.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)

            // Primary CTA
            Button {
                requestLocation()
            } label: {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14))
                    Text("Enable Location")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(creamText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(
                            LinearGradient(
                                colors: [greenTop, greenBottom],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(gold.opacity(0.15), lineWidth: 1)
                        )
                )
            }
            .padding(.bottom, 16)

            // Fallback
            Button {
                advancePage()
            } label: {
                Text("or enter city manually")
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(inkDark.opacity(0.45))
                    .underline(true, color: inkDark.opacity(0.3))
            }
        }
    }

    // MARK: - Page 2 — Prayer Method

    private var prayerMethodPageContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Prayer Method")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(inkDark)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 24)

            VStack(spacing: 10) {
                ForEach(PrayerMethod.allCases) { method in
                    methodRow(method)
                }
            }
        }
    }

    private func methodRow(_ method: PrayerMethod) -> some View {
        let isSelected = selectedMethod == method

        return Button {
            HapticManager.shared.selectionChanged()
            selectedMethod = method
        } label: {
            HStack(spacing: 14) {
                // Radio indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? greenTop : inkDark.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 20, height: 20)

                    if isSelected {
                        Circle()
                            .fill(greenTop)
                            .frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(method.rawValue)
                        .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? inkDark : inkDark.opacity(0.65))

                    Text(method.subtitle)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(inkDark.opacity(0.45))
                }

                Spacer()
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected
                          ? greenTop.opacity(0.08)
                          : Color(red: 0.941, green: 0.910, blue: 0.855))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(isSelected ? greenTop.opacity(0.35) : inkDark.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.18), value: isSelected)
    }

    // MARK: - Page 3 — Notifications

    private var notificationsPageContent: some View {
        VStack(spacing: 0) {
            Text("Stay Connected")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(inkDark)
                .padding(.bottom, 8)

            Text("Customise how Kheir keeps you on track.")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(inkDark.opacity(0.55))
                .multilineTextAlignment(.center)
                .padding(.bottom, 28)

            // Toggle rows
            VStack(spacing: 12) {
                notificationToggleRow(
                    icon: "bell.badge",
                    title: "Prayer Notifications",
                    subtitle: "Reminders at prayer times",
                    isOn: $prayerNotificationsOn
                )

                notificationToggleRow(
                    icon: "text.book.closed",
                    title: "Daily Ayah",
                    subtitle: "A verse each morning",
                    isOn: $dailyAyahOn
                )
            }
            .padding(.bottom, 32)

            // Begin CTA
            Button {
                complete()
            } label: {
                Text("Begin Your Journey")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(creamText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(
                                LinearGradient(
                                    colors: [greenTop, greenBottom],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(gold.opacity(0.15), lineWidth: 1)
                            )
                    )
            }
        }
    }

    private func notificationToggleRow(
        icon: String,
        title: String,
        subtitle: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .light))
                .foregroundStyle(greenTop)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(inkDark)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(inkDark.opacity(0.5))
            }

            Spacer()

            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(greenTop)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.941, green: 0.910, blue: 0.855))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(inkDark.opacity(0.12), lineWidth: 1)
                )
        )
    }

    // MARK: - Skip Button

    private var skipButton: some View {
        Button {
            complete()
        } label: {
            Text("Skip")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(gold.opacity(0.75))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .padding(.top, 12)
        .padding(.trailing, 8)
    }

    // MARK: - Gesture

    private func pageDragGesture(page: Int, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .global)
            .onChanged { value in
                isFlipping = true
                let delta = -value.translation.width
                let raw   = delta / size.width
                flipProgress = max(-0.15, min(1, raw))  // slight back-drag allowed
            }
            .onEnded { value in
                isFlipping = false
                let elapsed  = 0.001  // avoids division-by-zero; velocity calc below
                let velocity = -Double(value.predictedEndTranslation.width - value.translation.width) / elapsed

                let shouldAdvance = value.translation.width < -60 || velocity > 300
                let shouldGoBack  = value.translation.width > 60  || velocity < -300

                HapticManager.shared.softTap()

                if shouldAdvance && page < totalPages {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        flipProgress = 1
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.28))
                        flipProgress = 0
                        isFlipping   = false
                        flowState    = .open(page: page + 1)
                    }
                } else if shouldGoBack && page > 1 {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        flipProgress = 0
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(0.28))
                        flipProgress = 0
                        isFlipping   = false
                        flowState    = .open(page: page - 1)
                    }
                } else {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                        flipProgress = 0
                    }
                }
            }
    }

    // MARK: - Actions

    private func openBook() {
        if reduceMotion {
            flowState = .open(page: 1)
            return
        }

        withAnimation(.spring(response: 0.7, dampingFraction: 0.80)) {
            coverOpenProgress = 1
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.55))
            flowState         = .open(page: 1)
            coverOpenProgress = 0
        }
    }

    private func requestLocation() {
        LocationService.shared.requestPermission()
        locationGranted = true
        HapticManager.shared.lightTap()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.3))
            advancePage()
        }
    }

    private func advancePage() {
        guard case .open(let current) = flowState else { return }
        if current < totalPages {
            if reduceMotion {
                flowState = .open(page: current + 1)
                return
            }
            withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                flipProgress = 1
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.28))
                flipProgress = 0
                flowState    = .open(page: current + 1)
            }
        } else {
            complete()
        }
    }

    private func complete() {
        HapticManager.shared.success()
        hasCompletedOnboarding = true
    }

    // MARK: - Layout helpers

    private func bookWidth(for size: CGSize) -> CGFloat {
        min(size.width - 48, 340)
    }

    private func bookHeight(for size: CGSize) -> CGFloat {
        min(size.height - 120, 520)
    }
}

// MARK: - Preview

#Preview("Closed") {
    OnboardingView()
}

#Preview("Page 1") {
    // Simulates the view with AppStorage defaulted to false
    OnboardingView()
}
