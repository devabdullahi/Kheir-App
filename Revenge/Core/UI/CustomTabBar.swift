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
                PaperIconView(tab.paperIcon, size: isSelected ? 22 : 19)
                    .saturation(isSelected ? 1 : 0.7)
                    .opacity(isSelected ? 1 : 0.85)
                    .frame(height: 23)

                Text(tab.title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(isSelected ? TabPaper.selectedInk : TabPaper.ink(scheme))
            .opacity(isSelected ? 1 : 0.72)
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
    @Namespace private var tagNamespace
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.rawValue) { tab in
                TabButton(tab: tab, isSelected: selectedTab == tab, tagNamespace: tagNamespace) {
                    guard selectedTab != tab else { return }
                    HapticManager.shared.lightTap()
                    // The tag slides to the new tab: ease-out, no bounce.
                    withAnimation(.open(0.25)) {
                        selectedTab = tab
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .paperPiece(TabPaper.strip(scheme), material: .kraft, depth: 1.4, edge: .torn, radius: 3, seed: 77, padding: nil)
        .overlay(alignment: .leading) { BrassBrad(size: 8).padding(.leading, 5) }
        .overlay(alignment: .trailing) { BrassBrad(size: 8).padding(.trailing, 5) }
        .padding(.horizontal, 12)
        .padding(.bottom, 28)
        // Scroll-reactive visibility
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 80)
        .animation(.open(0.3), value: isVisible)
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
