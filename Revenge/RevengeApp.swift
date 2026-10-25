import SwiftUI

@main
struct RevengeApp: App {
    init() {
        // Notification delegate + PRAYER_TIME actions must exist before any
        // notification action can launch the app in the background.
        NotificationService.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            SplashScreenView()
                .task {
                    // Request location after UI is up — non-blocking
                    LocationService.shared.requestPermission()
                    LocationService.shared.startUpdating()
                }
        }
    }
}
