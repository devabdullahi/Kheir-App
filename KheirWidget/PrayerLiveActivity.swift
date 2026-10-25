import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Prayer countdown Live Activity UI
//
// Lock Screen: navy cardstock with a torn edge, the coming prayer, a live
// countdown and a torn progress strip where a paper sun travels from the
// previous prayer toward this one. Dynamic Island: icon + countdown when compact,
// the same strip and two buttons when expanded.
//
// The countdown runs live (`Text(timerInterval:)`). The sun's position is drawn
// when the system renders the activity (start, each app update, and when it goes
// stale at prayer time); the app nudges it along while it is in the foreground.

struct PrayerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PrayerCountdownAttributes.self) { context in
            PrayerLockScreenView(state: context.state, isStale: context.isStale)
                .activityBackgroundTint(WPalette.navy)
                .activitySystemActionForegroundColor(WPalette.creamInk)
                .widgetURL(URL(string: "kheir://prayer"))
        } dynamicIsland: { context in
            let state = context.state
            let icon = WIcon(prayer: state.prayerName)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        WPaperIcon(icon, size: 28)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(state.prayerName)
                                .font(.system(size: 15, weight: .black, design: .rounded))
                            Text(state.prayerTime, format: .dateTime.hour().minute())
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(WPalette.creamInk.opacity(0.6))
                        }
                    }
                    .foregroundStyle(WPalette.creamInk)
                    .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(state: state, isStale: context.isStale)
                        .font(.system(size: 26, weight: .black, design: .rounded))
                        .foregroundStyle(WPalette.mustard)
                        .frame(maxWidth: 96, alignment: .trailing)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 10) {
                        PaperSunStrip(state: state)
                        HStack(spacing: 8) {
                            Button(intent: MuteUntilAthanIntent()) {
                                Text("Mute till athan")
                                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(WPalette.leaf, in: RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            Link(destination: URL(string: "kheir://qibla")!) {
                                HStack(spacing: 5) {
                                    WPaperIcon(.compass, size: 14)
                                    Text("Qibla")
                                        .font(.system(size: 12, weight: .heavy, design: .rounded))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(WPalette.navy, in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                        .foregroundStyle(WPalette.creamInk)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                WPaperIcon(icon, size: 18)
            } compactTrailing: {
                CountdownText(state: state, isStale: context.isStale)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundStyle(WPalette.mustard)
                    .frame(maxWidth: 48)
            } minimal: {
                WPaperIcon(icon, size: 18)
            }
            .keylineTint(WPalette.mustard)
            .widgetURL(URL(string: "kheir://prayer"))
        }
    }
}

// MARK: - Pieces

/// Live countdown to the prayer; "now" once the prayer time has passed.
private struct CountdownText: View {
    let state: PrayerCountdownAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if isStale || state.prayerTime <= Date() {
            Text("now")
        } else {
            Text(timerInterval: Date()...state.prayerTime, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }
}

struct PrayerLockScreenView: View {
    let state: PrayerCountdownAttributes.ContentState
    let isStale: Bool

    private var arrived: Bool { isStale || state.prayerTime <= Date() }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                HStack(spacing: 10) {
                    PrayerThumb(prayer: state.prayerName, size: 42)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(arrived ? "Athan · now" : "Next prayer")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1)
                            .textCase(.uppercase)
                            .foregroundStyle(WPalette.mustard)
                        Text(arrived ? "\(state.prayerName) — now" : state.prayerName)
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .lineLimit(1)
                        HStack(spacing: 0) {
                            Text(state.prayerTime, format: .dateTime.hour().minute())
                            Text(" · \(state.moment)")
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(WPalette.creamInk.opacity(0.65))
                    }
                }
                Spacer(minLength: 8)
                if !arrived {
                    VStack(alignment: .trailing, spacing: 3) {
                        CountdownText(state: state, isStale: isStale)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(WPalette.mustard)
                            .frame(maxWidth: 120, alignment: .trailing)
                        Text("remaining")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(WPalette.creamInk.opacity(0.6))
                    }
                }
            }
            PaperSunStrip(state: state)
        }
        .foregroundStyle(WPalette.creamInk)
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background { NavyCardstock() }
    }
}

/// Navy cardstock: grain, lamp light and a torn darker sheet along the bottom.
private struct NavyCardstock: View {
    var body: some View {
        ZStack {
            WPaperSheet(color: WPalette.navy, seed: 510)
            WTornHill(baseline: 0.86, amplitude: 3, seed: 511)
                .fill(WPalette.indigo.opacity(0.7))
                .wPaperShadow(depth: 0.5)
        }
        .environment(\.colorScheme, .dark)
    }
}

/// The torn progress strip with a paper sun travelling along it.
struct PaperSunStrip: View {
    let state: PrayerCountdownAttributes.ContentState

    static func short(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.defaultDigits(amPM: .omitted)).minute())
    }

    var body: some View {
        let p = state.progress(at: Date())
        VStack(spacing: 2) {
            GeometryReader { geo in
                let w = geo.size.width - 22   // leave room for the destination icon
                ZStack(alignment: .leading) {
                    WTornStrip(seed: 512)
                        .fill(WPalette.creamInk.opacity(0.16))
                        .frame(width: w, height: 9)
                    WTornStrip(seed: 513)
                        .fill(LinearGradient(colors: [WPalette.mustard, WPalette.terracotta], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(6, w * p), height: 9)
                        .wPaperShadow(depth: 0.4)
                    WPaperIcon(.sun, size: 22)
                        .offset(x: max(0, w * p - 11))
                    WPaperIcon(WIcon(prayer: state.prayerName), size: 22)
                        .offset(x: w + 1)
                }
                .frame(height: 26)
            }
            .frame(height: 26)
            HStack {
                Text(verbatim: "\(state.previousName) \(Self.short(state.previousTime))")
                Spacer()
                Text(verbatim: "\(state.prayerName) \(Self.short(state.prayerTime))")
            }
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(WPalette.creamInk.opacity(0.6))
        }
    }
}

/// A tiny paper scene for the coming prayer: sky, torn hills and the prayer icon.
struct PrayerThumb: View {
    let prayer: String
    var size: CGFloat = 42

    private var sky: [Color] {
        switch prayer {
        case "Fajr": [0x1A2744, 0x3A5A7A, 0xD4926B].map { WPalette.hex($0) }
        case "Sunrise": [0x4A7FA5, 0xC4D8E0, 0xF5D5A0].map { WPalette.hex($0) }
        case "Dhuhr": [0x1976A8, 0x5AB8D4, 0xB0E0EC].map { WPalette.hex($0) }
        case "Asr": [0x3A7A9A, 0x8ABAC4, 0xD4A86B].map { WPalette.hex($0) }
        case "Maghrib": [0x2A1A3A, 0x8B2E1A, 0xD4694A].map { WPalette.hex($0) }
        default: [0x050A14, 0x0D1A2A, 0x1A2744].map { WPalette.hex($0) }
        }
    }

    var body: some View {
        ZStack {
            sky[0]
            WTornHill(baseline: 0.48, amplitude: 1.5, seed: 31).fill(sky[1])
            WTornHill(baseline: 0.68, amplitude: 1.5, seed: 32).fill(sky[2])
            // A sun or moon over the scene (the prayer icons carry their own hills).
            WPaperIcon(prayer == "Fajr" || prayer == "Isha" ? .moon : .sun, size: size * 0.55)
                .offset(y: -size * 0.1)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24))
        .wPaperShadow(depth: 0.6)
    }
}

// MARK: - Previews

extension PrayerCountdownAttributes.ContentState {
    static var preview: Self {
        let now = Date()
        return .init(
            prayerName: "Maghrib",
            prayerTime: now.addingTimeInterval(14 * 60 + 52),
            previousName: "Asr",
            previousTime: now.addingTimeInterval(-2 * 3600 - 15 * 60)
        )
    }
}

#Preview("Lock Screen", as: .content, using: PrayerCountdownAttributes(prayerID: "preview")) {
    PrayerLiveActivity()
} contentStates: {
    PrayerCountdownAttributes.ContentState.preview
}

#Preview("Island expanded", as: .dynamicIsland(.expanded), using: PrayerCountdownAttributes(prayerID: "preview")) {
    PrayerLiveActivity()
} contentStates: {
    PrayerCountdownAttributes.ContentState.preview
}
