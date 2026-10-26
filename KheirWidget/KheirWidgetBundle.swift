import WidgetKit
import SwiftUI

/// Entry point for the KheirWidget extension.
@main
struct KheirWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlowerVerseWidget()
        PrayerFlowerWidget()
        NextPrayerWidget()
        GardenWidget()
        DailyAyahWidget()
        PrayerLiveActivity()
    }
}
