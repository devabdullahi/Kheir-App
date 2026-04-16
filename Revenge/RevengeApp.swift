import SwiftUI

@main
struct RevengeApp: App {
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
