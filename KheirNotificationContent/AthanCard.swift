import SwiftUI

// A self-contained paper card (the extension can't see the app's PaperKit).

private extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: .alphanumerics.inverted)).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

private func seeded(_ i: Int, _ salt: Double = 0) -> Double {
    let x = sin(Double(i) * 12.9898 + salt * 78.233) * 43758.5453
    return x - floor(x)
}

/// Sky bands for each prayer, top to bottom.
private func skyBands(_ prayer: String) -> [Color] {
    switch prayer.lowercased() {
    case "fajr": ["#1A2744", "#3A5A7A", "#D4926B", "#E8B87A"].map(Color.init(hex:))
    case "dhuhr": ["#1976A8", "#2E98C4", "#5AB8D4", "#8AD0E0"].map(Color.init(hex:))
    case "asr": ["#3A7A9A", "#5A9AB4", "#C4B88A", "#D4A86B"].map(Color.init(hex:))
    case "maghrib": ["#2A1A3A", "#8B2E1A", "#D4694A", "#E8A87A"].map(Color.init(hex:))
    default: ["#0A1020", "#141A33", "#1E2442", "#2B3560"].map(Color.init(hex:))
    }
}

private func tornLine(width: CGFloat, y: CGFloat, amp: CGFloat, seed: Int) -> [CGPoint] {
    stride(from: CGFloat(-4), through: width + 4, by: 4).enumerated().map { k, x in
        let roll = sin(Double(x) / 61 + seeded(seed, 5) * 6.28) * 0.6 + sin(Double(x) / 23 + seeded(seed, 6) * 6.28) * 0.4
        return CGPoint(x: x, y: y + CGFloat(roll) * amp + CGFloat(seeded(k, Double(seed) + 7) - 0.5) * 2.4)
    }
}

struct AthanCard: View {
    let prayer: String
    let time: Date

    private var line: String {
        switch prayer.lowercased() {
        case "fajr": "Prayer is better than sleep."
        case "dhuhr": Calendar.current.component(.weekday, from: time) == 6 ? "It's Jumuʿah." : "The sun has passed its height."
        case "asr": "The afternoon is turning."
        case "maghrib": "The sun has set."
        case "isha": "The night has come."
        default: "Come to prayer."
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            sky
                .frame(height: 118)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ATHAN · NOW")
                            .font(.system(size: 11, weight: .heavy, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(Color(hex: "#C98F22"))
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(prayer)
                                .font(.system(size: 26, weight: .black, design: .rounded))
                            Text(time.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 22, weight: .black, design: .rounded))
                                .foregroundStyle(Color(hex: "#C98F22"))
                        }
                    }
                    Spacer()
                }
                Text("حَيَّ عَلَى ٱلصَّلَاةِ")
                    .font(.system(size: 26, weight: .semibold))
                    .frame(maxWidth: .infinity)
                Text("Come to prayer — \(line.prefix(1).lowercased() + line.dropFirst())")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(hex: "#6E5E4A"))
                    .frame(maxWidth: .infinity)
                AthanBars()
                    .frame(height: 22)
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(Color(hex: "#2B2118"))
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: "#FBF5E8"))
                    .shadow(color: Color(red: 0.12, green: 0.07, blue: 0.02).opacity(0.25), radius: 5, x: 1.5, y: 3)
            }
            .rotationEffect(.degrees(-0.6))
            .padding(.horizontal, 14)
            .padding(.top, -24)
            Spacer(minLength: 12)
        }
        .background(Color(hex: "#E9DCC2"))
    }

    private var sky: some View {
        let bands = skyBands(prayer)
        let isNight = prayer.lowercased() == "isha"
        return Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .color(bands[0]))
            for k in 1..<bands.count {
                let y = size.height * CGFloat(k) / CGFloat(bands.count) * 0.9
                var p = Path()
                p.move(to: CGPoint(x: -4, y: size.height + 4))
                tornLine(width: size.width, y: y, amp: 4, seed: 200 + k).forEach { p.addLine(to: $0) }
                p.addLine(to: CGPoint(x: size.width + 4, y: size.height + 4))
                ctx.drawLayer { l in
                    l.addFilter(.shadow(color: .black.opacity(0.25), radius: 2, x: 0.6, y: 1.2))
                    l.fill(p, with: .color(bands[k]))
                }
            }
            ctx.drawLayer { l in
                l.addFilter(.shadow(color: .black.opacity(0.3), radius: 3, x: 1.5, y: 3))
                if isNight {
                    let c = CGPoint(x: size.width * 0.72, y: size.height * 0.42)
                    let disc = Path(ellipseIn: CGRect(x: c.x - 22, y: c.y - 22, width: 44, height: 44))
                    let bite = Path(ellipseIn: CGRect(x: c.x - 12, y: c.y - 26, width: 44, height: 44))
                    l.fill(disc.subtracting(bite), with: .color(Color(hex: "#F6EBC8")))
                } else {
                    let c = CGPoint(x: size.width * 0.72, y: size.height * (prayer.lowercased() == "maghrib" || prayer.lowercased() == "fajr" ? 0.78 : 0.42))
                    var rays = Path()
                    for k in 0..<12 {
                        let a = Double(k) / 12 * .pi * 2
                        rays.move(to: CGPoint(x: c.x + cos(a - 0.12) * 26, y: c.y + sin(a - 0.12) * 26))
                        rays.addLine(to: CGPoint(x: c.x + cos(a) * 42, y: c.y + sin(a) * 42))
                        rays.addLine(to: CGPoint(x: c.x + cos(a + 0.12) * 26, y: c.y + sin(a + 0.12) * 26))
                        rays.closeSubpath()
                    }
                    l.fill(rays, with: .color(Color(hex: "#F2A93B")))
                    l.fill(Path(ellipseIn: CGRect(x: c.x - 26, y: c.y - 26, width: 52, height: 52)), with: .color(Color(hex: "#F7B733")))
                    l.fill(Path(ellipseIn: CGRect(x: c.x - 19, y: c.y - 19, width: 34, height: 34)), with: .color(Color(hex: "#FFE08A")))
                }
            }
            // Hills with a small masjid.
            var hill = Path()
            hill.move(to: CGPoint(x: -4, y: size.height + 4))
            tornLine(width: size.width, y: size.height * 0.86, amp: 5, seed: 300).forEach { hill.addLine(to: $0) }
            hill.addLine(to: CGPoint(x: size.width + 4, y: size.height + 4))
            ctx.fill(hill, with: .color(Color(hex: isNight ? "#1F3A30" : "#4E8A5A")))
            let mx = size.width * 0.28, my = size.height * 0.86
            var masjid = Path(CGRect(x: mx - 16, y: my - 12, width: 32, height: 14))
            masjid.addEllipse(in: CGRect(x: mx - 11, y: my - 30, width: 22, height: 24))
            masjid.addRect(CGRect(x: mx + 20, y: my - 34, width: 4, height: 36))
            ctx.fill(masjid, with: .color(Color(hex: "#1F3A30")))
        }
    }
}

/// Paper bars rising and falling while the athan plays.
private struct AthanBars: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<9, id: \.self) { i in
                    let h = 5 + 15 * abs(sin(t * (2.1 + seeded(i, 1)) + seeded(i, 2) * 6))
                    RoundedRectangle(cornerRadius: 1)
                        .fill(Color(hex: "#E3B65A"))
                        .frame(width: 5, height: h)
                        .shadow(color: .black.opacity(0.25), radius: 0.6, x: 0.4, y: 0.8)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
