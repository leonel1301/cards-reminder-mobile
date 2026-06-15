import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
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
