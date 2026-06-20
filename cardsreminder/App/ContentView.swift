import SwiftUI

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CardsAPIService.self) private var cardsService
    @Environment(PaymentsAPIService.self) private var paymentsService

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
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                cardsService.cancelInFlightRequests()
                paymentsService.cancelInFlightRequests()
            case .active:
                Task {
                    await cardsService.refreshOnForeground()
                    await paymentsService.refreshOnForeground()
                }
            default:
                break
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(CardsAPIService())
        .environment(PaymentsAPIService())
}
