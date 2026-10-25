import SwiftUI

// MARK: - Paper Icons
//
// Every icon in the app is a small cut-paper piece with its own calm idle motion
// (suns rise and turn, the moon rocks, the bell rings in bursts). Screens use
// `PaperIconView(.asr)` and never draw icons themselves, so the art can evolve
// in one place. Widgets and Live Activities pass `animated: false`, because iOS
// doesn't run custom animation there.

enum PaperIcon: String, CaseIterable, Sendable {
    // Tabs and navigation
    case house, book, bookmark, compass, clock, gear, search, share, plus, aa
    // Prayers and sky
    case fajr, sunrise, dhuhr, asr, maghrib, isha, sun, moon, star
    // Practice and progress
    case sprout, beads, pen, bell, lantern
    // Places and trust
    case masjid, pin, shield, widget
    // Player
    case play, pause, previous, next

    /// The icon for a prayer name as it appears in prayer data ("Fajr", "Sunrise", …).
    static func forPrayer(_ name: String) -> PaperIcon {
        switch name.lowercased() {
        case "fajr": .fajr
        case "sunrise", "shuruq": .sunrise
        case "dhuhr", "zuhr", "jumuah", "jumu'ah": .dhuhr
        case "asr": .asr
        case "maghrib": .maghrib
        case "isha": .isha
        default: .sun
        }
    }

    /// SF Symbol used until the paper art for this icon is drawn.
    var fallbackSymbol: String {
        switch self {
        case .house: "house.fill"
        case .book: "book.fill"
        case .bookmark: "bookmark.fill"
        case .compass: "safari.fill"
        case .clock: "clock.fill"
        case .gear: "gearshape.fill"
        case .search: "magnifyingglass"
        case .share: "square.and.arrow.up"
        case .plus: "plus"
        case .aa: "textformat.size"
        case .fajr: "sunrise.fill"
        case .sunrise: "sun.horizon.fill"
        case .dhuhr, .sun: "sun.max.fill"
        case .asr: "sun.haze.fill"
        case .maghrib: "sunset.fill"
        case .isha, .moon: "moon.stars.fill"
        case .star: "star.fill"
        case .sprout: "leaf.fill"
        case .beads: "circle.dotted"
        case .pen: "pencil"
        case .bell: "bell.fill"
        case .lantern: "lamp.desk.fill"
        case .masjid: "building.columns.fill"
        case .pin: "mappin"
        case .shield: "lock.shield.fill"
        case .widget: "square.grid.2x2.fill"
        case .play: "play.fill"
        case .pause: "pause.fill"
        case .previous: "backward.end.fill"
        case .next: "forward.end.fill"
        }
    }
}

/// A paper icon. `animated: false` for widgets, Live Activities and share images.
struct PaperIconView: View {
    let icon: PaperIcon
    var size: CGFloat = 22
    var animated: Bool = true

    init(_ icon: PaperIcon, size: CGFloat = 22, animated: Bool = true) {
        self.icon = icon
        self.size = size
        self.animated = animated
    }

    var body: some View {
        Image(systemName: icon.fallbackSymbol)
            .font(.system(size: size * 0.8, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(Color.islamicGold)
            .frame(width: size, height: size)
            .paperShadow(depth: 0.4)
            .accessibilityHidden(true)
    }
}
