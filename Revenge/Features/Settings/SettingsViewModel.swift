import Foundation
import SwiftUI
import Combine

final class SettingsViewModel: ObservableObject {
    @Published var settings = AppSettings.shared

    let appVersion: String = {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }()

    let buildNumber: String = {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }()
}
