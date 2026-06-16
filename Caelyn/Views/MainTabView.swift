import SwiftUI

struct MainTabView: View {
    @State private var selection: Tab = .home
    @State private var iPadSelection: Tab? = .home
    @State private var router = NotificationRouter.shared
    @Environment(\.horizontalSizeClass) private var hSizeClass

    enum Tab: Hashable, CaseIterable {
        case home, calendar, log, insights, settings

        var label: String {
            switch self {
            case .home:     return "Home"
            case .calendar: return "Calendar"
            case .log:      return "Log"
            case .insights: return "Insights"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .home:     return "house"
            case .calendar: return "calendar"
            case .log:      return "square.and.pencil"
            case .insights: return "chart.bar"
            case .settings: return "gearshape"
            }
        }

        var selectedIcon: String {
            switch self {
            case .home:     return "house.fill"
            case .calendar: return "calendar.badge.checkmark"
            case .log:      return "square.and.pencil.circle.fill"
            case .insights: return "chart.bar.fill"
            case .settings: return "gearshape.fill"
            }
        }

        @ViewBuilder
        var destination: some View {
            switch self {
            case .home:     HomeView()
            case .calendar: CalendarView()
            case .log:      LogView()
            case .insights: InsightsView()
            case .settings: SettingsView()
            }
        }
    }

    var body: some View {
        if hSizeClass == .regular {
            ipadLayout
        } else {
            iPhoneLayout
        }
    }

    // MARK: - iPad: sidebar + detail split

    private var ipadLayout: some View {
        NavigationSplitView {
            List(selection: $iPadSelection) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Label(tab.label, systemImage: iPadSelection == tab ? tab.selectedIcon : tab.icon)
                        .tag(tab)
                }
            }
            .navigationTitle("Caelyn")
            .listStyle(.sidebar)
            .tint(CaelynColor.primaryPlum)
        } detail: {
            (iPadSelection ?? .home).destination
        }
        .tint(CaelynColor.primaryPlum)
        .environment(\.highlightedNotificationCategory, router.highlightedCategory)
        .onChange(of: router.pendingCategory) { _, newCategory in
            handlePendingCategory(newCategory)
        }
    }

    // MARK: - iPhone: tab bar

    private var iPhoneLayout: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: selection == .home ? "house.fill" : "house")
                }
                .tag(Tab.home)

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: selection == .calendar ? "calendar.badge.checkmark" : "calendar")
                }
                .tag(Tab.calendar)

            LogView()
                .tabItem {
                    Label("Log", systemImage: selection == .log ? "square.and.pencil.circle.fill" : "square.and.pencil")
                }
                .tag(Tab.log)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: selection == .insights ? "chart.bar.fill" : "chart.bar")
                }
                .tag(Tab.insights)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: selection == .settings ? "gearshape.fill" : "gearshape")
                }
                .tag(Tab.settings)
        }
        .tint(CaelynColor.primaryPlum)
        .environment(\.highlightedNotificationCategory, router.highlightedCategory)
        .onChange(of: router.pendingCategory) { _, newCategory in
            handlePendingCategory(newCategory)
        }
    }

    /// Tap routing: which tab a given notification opens.
    private func tab(for category: NotificationService.Category) -> Tab {
        switch category {
        case .dailyCheckIn, .periodUpcoming, .ovulation:
            return .home
        case .medication, .birthControl:
            return .log
        }
    }

    /// When a notification tap arrives, switch to the right tab, briefly mark
    /// the matching card for a soft pulse, and clear after ~2.5 seconds.
    private func handlePendingCategory(_ category: NotificationService.Category?) {
        guard let category else { return }
        let target = tab(for: category)
        selection = target
        iPadSelection = target
        router.highlightedCategory = category
        router.pendingCategory = nil
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            // Clear only if no newer tap has overwritten it.
            if router.highlightedCategory == category {
                router.highlightedCategory = nil
            }
        }
    }
}

// MARK: - Highlight environment

/// Carries which notification category, if any, just routed the user here.
/// Cards on Home / Log can read this and pulse softly when their category matches.
private struct HighlightedNotificationCategoryKey: EnvironmentKey {
    static let defaultValue: NotificationService.Category? = nil
}

extension EnvironmentValues {
    var highlightedNotificationCategory: NotificationService.Category? {
        get { self[HighlightedNotificationCategoryKey.self] }
        set { self[HighlightedNotificationCategoryKey.self] = newValue }
    }
}

#Preview {
    MainTabView()
        .modelContainer(Persistence.preview)
}
