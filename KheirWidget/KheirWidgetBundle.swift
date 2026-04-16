import WidgetKit
import SwiftUI

/// Entry point for the KheirWidget extension.
/// Add additional Widget conformances to `body` as the widget catalogue grows.
@main
struct KheirWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyAyahWidget()
    }
}
