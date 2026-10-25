import SwiftUI

struct ContentView: View {
    private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: TabItem = .home
    @State private var isTabBarVisible = true
    /// Changing a tab's ID resets its navigation (tap the current tab to go back to its root).
    @State private var stackIDs: [TabItem: UUID] = Dictionary(uniqueKeysWithValues: TabItem.allCases.map { ($0, UUID()) })
    /// For `AppTheme.sky`: true between Fajr and Maghrib.
    @State private var isDaytime = SkyThemeClock.fallbackIsDaytime(.now)
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch selectedTab {
            case .home:
                NavigationStack { HomeView() }.id(stackIDs[.home])
            case .quran:
                NavigationStack { SurahListView() }.id(stackIDs[.quran])
            case .saved:
                NavigationStack { BookmarksView() }.id(stackIDs[.saved])
            case .qibla:
                NavigationStack { QiblaView() }.id(stackIDs[.qibla])
            case .prayer:
                NavigationStack { PrayerTimesView() }.id(stackIDs[.prayer])
            }
        }
        .safeAreaInset(edge: .bottom) {
            CustomTabBar(selectedTab: $selectedTab, isVisible: $isTabBarVisible) { tab in
                // A fresh identity pops the tab's NavigationStack back to its root.
                withAnimation(.open(0.25)) { stackIDs[tab] = UUID() }
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
        // Screenshots: `-startLiveActivity` starts the prayer countdown a few seconds in.
        .task {
            guard ProcessInfo.processInfo.arguments.contains("-startLiveActivity") else { return }
            try? await Task.sleep(for: .seconds(6))
            if let problem = await PrayerLiveActivityManager.shared.startNow() { print("LiveActivity:", problem) }
        }
        #endif
    }

    /// kheir://qibla, kheir://prayer, kheir://home/ayah
    private func open(_ url: URL) {
        guard url.scheme == "kheir" else { return }
        switch url.host() {
        case "qibla": selectedTab = .qibla
        case "prayer": selectedTab = .prayer
        case "home":
            selectedTab = .home
            stackIDs[.home] = UUID()
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
