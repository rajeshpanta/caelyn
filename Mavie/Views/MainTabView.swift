import SwiftUI

struct MainTabView: View {
    @State private var selection: Tab = .home

    enum Tab: Hashable {
        case home, calendar, log, insights, settings
    }

    var body: some View {
        TabView(selection: $selection) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: selection == .home ? "house.fill" : "house")
                }
                .tag(Tab.home)

            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: selection == .calendar ? "calendar" : "calendar")
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
        .tint(MavieColor.primaryPlum)
    }
}

#Preview {
    MainTabView()
        .modelContainer(Persistence.preview)
}
