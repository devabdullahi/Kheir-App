import SwiftUI

// MARK: - Tab Item Model

enum TabItem: Int, CaseIterable {
    case home, quran, saved, qibla, prayer

    var title: String {
        switch self {
        case .home:   return "Home"
        case .quran:  return "Quran"
        case .saved:  return "Saved"
        case .qibla:  return "Qibla"
        case .prayer: return "Prayer"
        }
    }

    /// Outlined SF Symbol for inactive state.
    var icon: String {
        switch self {
        case .home:   return "house"
        case .quran:  return "book"
        case .saved:  return "bookmark"
        case .qibla:  return "safari"
        case .prayer: return "clock"
        }
    }

    /// Filled SF Symbol for active state.
    var iconFilled: String {
        switch self {
        case .home:   return "house.fill"
        case .quran:  return "book.fill"
        case .saved:  return "bookmark.fill"
        case .qibla:  return "safari.fill"
        case .prayer: return "clock.fill"
        }
    }
}

extension TabItem {
    /// The paper icon for this tab.
    var paperIcon: PaperIcon {
        switch self {
        case .home:   return .house
        case .quran:  return .book
        case .saved:  return .bookmark
        case .qibla:  return .compass
        case .prayer: return .clock
        }
    }
}

// MARK: - Palette

private enum TabPaper {
    static func strip(_ scheme: ColorScheme) -> Color { scheme == .dark ? Color(hex: "#5A3E36") : .paperKraft }
    static func ink(_ scheme: ColorScheme) -> Color { scheme == .dark ? .darkBodyText : Color(hex: "#3A2A1A") }
    static let selectedInk = Color(hex: "#2B2118")
}

// MARK: - Selected tag

/// The torn mustard tag the selected tab sits on. One tag slides between tabs.
private struct SelectedTag: View {
    var body: some View {
        Color.clear
            .paperPiece(.islamicGold, material: .construction, depth: 0.5, edge: .torn, radius: 2, seed: 5, padding: nil)
            .rotationEffect(.degrees(-2))
            .padding(.horizontal, -3)
            .padding(.vertical, -1)
    }
}

// MARK: - Individual Tab Button

private struct TabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let tagNamespace: Namespace.ID
    let action: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                PaperIconView(tab.paperIcon, size: isSelected ? 22 : 19, animated: false)
                    .saturation(isSelected ? 1 : 0.9)
                    .opacity(isSelected ? 1 : 0.95)
                    .frame(height: 23)

                Text(tab.title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? TabPaper.selectedInk : TabPaper.ink(scheme))
            .opacity(isSelected ? 1 : 0.88)
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background {
                if isSelected {
                    SelectedTag()
                        .matchedGeometryEffect(id: "selectedTabTag", in: tagNamespace)
                }
            }
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PaperPressStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Custom Tab Bar

/// A torn strip of kraft paper pinned to the table with a brass brad at each end.
struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    @Binding var isVisible: Bool
    /// Tapping the tab you're already on: return it to its first screen.
    var onReselect: (TabItem) -> Void = { _ in }
    @Namespace private var tagNamespace
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.rawValue) { tab in
                TabButton(tab: tab, isSelected: selectedTab == tab, tagNamespace: tagNamespace) {
                    guard selectedTab != tab else {
                        HapticManager.shared.lightTap()
                        onReselect(tab)
                        return
                    }
                    HapticManager.shared.lightTap()
                    // Content switches instantly, like any iOS tab bar; only the tag slides.
                    selectedTab = tab
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 2)
        // A full-width strip of kraft torn along its top edge, laid along the bottom of
        // the screen and running under the home indicator, so nothing shows beneath it.
        .background {
            TornTopStrip(seed: 77)
                .fill(TabPaper.strip(scheme))
                .overlay { PaperGrain(material: .kraft, seed: 77, dark: scheme == .dark).clipShape(TornTopStrip(seed: 77)) }
                .shadow(color: Color(red: 0.12, green: 0.07, blue: 0.02).opacity(0.22), radius: 6, x: 0, y: -2)
                .overlay(alignment: .topLeading) { BrassBrad(size: 8).padding(.leading, 10).padding(.top, 12) }
                .overlay(alignment: .topTrailing) { BrassBrad(size: 8).padding(.trailing, 10).padding(.top, 12) }
                .ignoresSafeArea(edges: .bottom)
        }
        // The tag slides to the new tab: ease-out, no bounce. Scoped to the bar only.
        .animation(.open(0.25), value: selectedTab)
        // Scroll-reactive visibility
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 80)
        .animation(.open(0.3), value: isVisible)
    }
}

/// A rectangle whose top edge is hand-torn.
struct TornTopStrip: Shape {
    var seed: Int = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        for point in PaperNoise.tornLine(width: rect.width, y: rect.minY + 4, amplitude: 2.5, seed: seed) {
            p.addLine(to: CGPoint(x: rect.minX + point.x, y: point.y))
        }
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}

// MARK: - Previews

#Preview("Custom Tab Bar — Active States") {
    struct PreviewWrapper: View {
        @State private var selectedTab: TabItem = .home
        @State private var isVisible: Bool = true

        var body: some View {
            ZStack {
                Color(red: 0.039, green: 0.059, blue: 0.118)
                    .ignoresSafeArea()

                VStack {
                    Text("Selected: \(selectedTab.title)")
                        .foregroundStyle(.white)
                        .font(.headline)

                    Toggle("Visible", isOn: $isVisible)
                        .padding(.horizontal, 40)
                        .foregroundStyle(.white)
                        .tint(Color(red: 0.133, green: 0.341, blue: 0.235))
                }

                CustomTabBar(selectedTab: $selectedTab, isVisible: $isVisible)
            }
        }
    }

    return PreviewWrapper()
}

#Preview("All Tabs") {
    struct AllTabsWrapper: View {
        @State private var selectedTab: TabItem = .quran
        @State private var isVisible: Bool = true

        var body: some View {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.039, green: 0.059, blue: 0.118),
                        Color(red: 0.051, green: 0.122, blue: 0.102)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                CustomTabBar(selectedTab: $selectedTab, isVisible: $isVisible)
            }
        }
    }

    return AllTabsWrapper()
}
