import SwiftUI

struct ContentView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: TabItem = .home
    @State private var isTabBarVisible = true

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                switch selectedTab {
                case .home:
                    NavigationStack { HomeView() }
                case .quran:
                    NavigationStack { SurahListView() }
                case .saved:
                    NavigationStack { BookmarksView() }
                case .qibla:
                    NavigationStack { QiblaView() }
                case .prayer:
                    NavigationStack { PrayerTimesView() }
                }
            }

            CustomTabBar(selectedTab: $selectedTab, isVisible: $isTabBarVisible)
        }
        .ignoresSafeArea(edges: .bottom)
        .preferredColorScheme(settings.appTheme.colorScheme)
    }
}
