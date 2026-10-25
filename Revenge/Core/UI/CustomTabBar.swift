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

// MARK: - Design Constants (local aliases for clarity)

private extension Color {
    /// Dark emerald — tab bar background overlay.
    static let tabBarOverlay = Color(red: 0.051, green: 0.122, blue: 0.102)
    /// Sacred garden primary green — active pill + border.
    static let tabBarBorder   = Color(red: 0.133, green: 0.341, blue: 0.235)
    /// Active pill fill.
    static let tabActivePill  = Color(red: 0.133, green: 0.341, blue: 0.235)
    /// Gold label for active tab.
    static let tabActiveLabel = Color(red: 0.831, green: 0.659, blue: 0.278)
    /// Warm cream label for inactive tabs.
    static let tabInactiveLabel = Color(red: 0.910, green: 0.863, blue: 0.784)
}

// MARK: - Individual Tab Button

private struct TabButton: View {
    let tab: TabItem
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: isSelected ? tab.iconFilled : tab.icon)
                    .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)

                Text(tab.title)
                    .font(.system(size: 10, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(
                isSelected
                    ? Color.tabActiveLabel
                    : Color.tabInactiveLabel.opacity(0.5)
            )
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 44, minHeight: 44)
            .background {
                if isSelected {
                    Capsule()
                        .fill(Color.tabActivePill.opacity(0.40))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(TabPressStyle())
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Press Animation Button Style

private struct TabPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? DesignTokens.pressScaleTab : 1.0)
            .animation(
                .spring(
                    response: DesignTokens.springResponse,
                    dampingFraction: DesignTokens.springDamping
                ),
                value: configuration.isPressed
            )
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: TabItem
    @Binding var isVisible: Bool

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TabItem.allCases, id: \.rawValue) { tab in
                TabButton(tab: tab, isSelected: selectedTab == tab) {
                    guard selectedTab != tab else { return }
                    HapticManager.shared.lightTap()
                    withAnimation(
                        .spring(
                            response: DesignTokens.springResponse,
                            dampingFraction: DesignTokens.springDamping
                        )
                    ) {
                        selectedTab = tab
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        // Pill container
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule()
                        .fill(Color.tabBarOverlay.opacity(0.85))
                }
                .overlay {
                    Capsule()
                        .strokeBorder(Color.tabBarBorder.opacity(0.25), lineWidth: 1)
                }
        }
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.30), radius: 12, x: 0, y: 6)
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
        // Scroll-reactive visibility
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : 80)
        .animation(
            .spring(
                response: DesignTokens.springResponse,
                dampingFraction: DesignTokens.springDamping
            ),
            value: isVisible
        )
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
