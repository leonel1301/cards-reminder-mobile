import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    private var timelineTabIcon: String {
        colorScheme == .dark ? "moon.fill" : "sun.max.fill"
    }

    var body: some View {
        TabView {
            TimelineView()
                .tabItem {
                    Label("tab_timeline", systemImage: timelineTabIcon)
                }

            CalendarView()
                .tabItem {
                    Label("tab_calendar", systemImage: "calendar")
                }

            CardsView()
                .tabItem {
                    Label("tab_cards", systemImage: "creditcard")
                }

            SettingsView()
                .tabItem {
                    Label("tab_settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
}
