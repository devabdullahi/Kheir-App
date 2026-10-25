import SwiftUI

struct ContentView: View {
    private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: TabItem = .home
    @State private var isTabBarVisible = true
    @State private var visitedTabs: Set<TabItem> = [.home]
    /// Each tab's navigation path. Emptying it pops back to the tab's first screen
    /// without rebuilding it (tap the current tab, or follow kheir://home).
    @State private var paths: [TabItem: NavigationPath] = [:]
    /// For `AppTheme.sky`: true between Fajr and Maghrib.
    @State private var isDaytime = SkyThemeClock.fallbackIsDaytime(.now)
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        // Every visited tab stays alive (no reload when switching back); hidden tabs
        // can't be touched and their animations pause.
        ZStack {
            ForEach(TabItem.allCases, id: \.self) { tab in
                if visitedTabs.contains(tab) {
                    let active = tab == selectedTab
                    NavigationStack(path: pathBinding(tab)) { root(for: tab) }
                        .opacity(active ? 1 : 0)
                        .allowsHitTesting(active)
                        .accessibilityHidden(!active)
                        .environment(\.motionPaused, !active)
                }
            }
        }
        .onChange(of: selectedTab, initial: true) { _, tab in visitedTabs.insert(tab) }
        .safeAreaInset(edge: .bottom) {
            CustomTabBar(selectedTab: $selectedTab, isVisible: $isTabBarVisible) { tab in
                paths[tab] = NavigationPath()
            }
        }
        .preferredColorScheme(resolvedScheme)
        .task(id: settings.appTheme) {
            guard settings.appTheme == .sky else { return }
            await followTheSky()
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            PrayerLiveActivityManager.shared.setForeground(phase == .active)
            if phase == .active {
                Task { await PrayerLiveActivityManager.shared.refresh() }
            }
        }
        // Widgets and the Live Activity open kheir:// links; notification taps post them.
        .onOpenURL(perform: open)
        .onReceive(NotificationCenter.default.publisher(for: .kheirOpenDeepLink)) { note in
            if let url = note.object as? URL { open(url) }
        }
        .task {
            if let url = NotificationService.shared.takePendingDeepLink() { open(url) }
        }
        #if DEBUG
        // Screenshots: `-openSettings` opens Settings on launch.
        .task {
            if ProcessInfo.processInfo.arguments.contains("-openSettings") { paths[.home] = NavigationPath([AppRoute.settings]) }
        }
        // Screenshots: `-startLiveActivity` starts the prayer countdown a few seconds in.
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-startLiveActivity") else { return }
            try? await Task.sleep(for: .seconds(6))
            if let problem = await PrayerLiveActivityManager.shared.startNow() { print("LiveActivity:", problem) }
        }
        #endif
    }

    @ViewBuilder
    private func root(for tab: TabItem) -> some View {
        Group {
            switch tab {
            case .home: HomeView()
            case .quran: SurahListView()
            case .saved: BookmarksView()
            case .qibla: QiblaView()
            case .prayer: PrayerTimesView()
            }
        }
        // Settings and its topics are pushed by value from any tab.
        .navigationDestination(for: AppRoute.self) { route in
            switch route {
            case .settings: SettingsView()
            case .settingsPage(let page): SettingsView(page: page)
            }
        }
    }

    private func pathBinding(_ tab: TabItem) -> Binding<NavigationPath> {
        Binding(get: { paths[tab] ?? NavigationPath() }, set: { paths[tab] = $0 })
    }

    /// kheir://qibla, kheir://prayer, kheir://home/ayah
    private func open(_ url: URL) {
        guard url.scheme == "kheir" else { return }
        switch url.host() {
        case "qibla": selectedTab = .qibla
        case "prayer": selectedTab = .prayer
        case "home":
            selectedTab = .home
            paths[.home] = NavigationPath()
        default: break
        }
    }

    private var resolvedScheme: ColorScheme? {
        settings.appTheme == .sky ? (isDaytime ? .light : .dark) : settings.appTheme.colorScheme
    }

    /// Re-checks once a minute while the Sky theme is on. Prayer times are fetched
    /// once per day (and retried until a location is known).
    private func followTheSky() async {
        var times: DayPrayerTimes?
        var timesDay: Int?
        while !Task.isCancelled {
            let now = Date.now
            let today = Calendar.current.ordinality(of: .day, in: .era, for: now)
            if times == nil || timesDay != today, let location = LocationService.shared.currentLocation {
                times = await PrayerTimesService.shared.fetchPrayerTimes(
                    coordinate: location,
                    date: now,
                    method: settings.calculationMethod,
                    madhab: settings.madhab
                )
                timesDay = today
            }
            let day = times.map { now >= $0.fajr && now < $0.maghrib } ?? SkyThemeClock.fallbackIsDaytime(now)
            if day != isDaytime {
                withAnimation(.travel(0.6)) { isDaytime = day }
            }
            try? await Task.sleep(for: .seconds(60))
        }
    }
}

enum SkyThemeClock {
    /// Before prayer times are known: day from 6 am to 6 pm.
    static func fallbackIsDaytime(_ date: Date) -> Bool {
        (6..<18).contains(Calendar.current.component(.hour, from: date))
    }
}
