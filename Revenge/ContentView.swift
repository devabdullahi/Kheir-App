import SwiftUI

struct ContentView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house")
                }

            SurahListView()
                .tabItem {
                    Label("Quran", systemImage: "book")
                }

            BookmarksView()
                .tabItem {
                    Label("Saved", systemImage: "bookmark")
                }

            QiblaView()
                .tabItem {
                    Label("Qibla", systemImage: "safari")
                }

            PrayerTimesView()
                .tabItem {
                    Label("Prayer", systemImage: "clock")
                }
        }
        .tint(Color.adaptivePrimary(colorScheme))
        .preferredColorScheme(settings.appTheme.colorScheme)
    }
}
