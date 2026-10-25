import SwiftUI

@main
struct KheirApp: App {
    init() {
        // Notification delegate + PRAYER_TIME actions must exist before any
        // notification action can launch the app in the background.
        NotificationService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .task {
                    // New users are asked on the onboarding location page, after it
                    // explains why; returning users just resume updates.
                    guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return }
                    LocationService.shared.requestPermission()
                    LocationService.shared.startUpdating()
                }
        }
    }
}
