import SwiftUI

/// The loading screen: the paper palm scene, then a crossfade into the app.
///
/// The first launch plays the full build (~2.4 s). Returning launches start
/// assembled and only show the idle scene with the hopping dates for a moment.
struct SplashScreenView: View {
    @State private var isActive = false
    @State private var showsSplash = true
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenLoadingBuild") private var hasSeenLoadingBuild = false
    /// Decided once at launch so flipping the flag doesn't swap the scene mid-play.
    @State private var playsBuild: Bool?

    var body: some View {
        ZStack {
            if isActive {
                if hasCompletedOnboarding {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }

            if showsSplash {
                PaperLoadingScene(playsBuild: playsBuild ?? !hasSeenLoadingBuild)
                    .accessibilityIdentifier("splashScreen")
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .task {
            let build = playsBuild ?? !hasSeenLoadingBuild
            playsBuild = build
            // Minimum time on screen: long enough for the build to finish, never a long wait.
            try? await Task.sleep(for: .milliseconds(build ? 2500 : 900))
            hasSeenLoadingBuild = true
            isActive = true
            withAnimation(.travel(0.4)) {
                showsSplash = false
            }
        }
    }
}
