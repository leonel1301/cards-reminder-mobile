import SwiftUI

private enum AppTab: Hashable {
    case timeline
    case calendar
    case cards
    case profile
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CardsAPIService.self) private var cardsService
    @Environment(PaymentsAPIService.self) private var paymentsService

    @State private var selectedTab: AppTab = .timeline

    private var timelineTabIcon: String {
        colorScheme == .dark ? "moon.fill" : "sun.max.fill"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TimelineView()
                .tabItem {
                    Label("tab_timeline", systemImage: timelineTabIcon)
                }
                .tag(AppTab.timeline)

            CalendarView()
                .tabItem {
                    Label("tab_calendar", systemImage: "calendar")
                }
                .tag(AppTab.calendar)

            CardsView()
                .tabItem {
                    Label("tab_cards", systemImage: "creditcard")
                }
                .tag(AppTab.cards)

            ProfileView()
                .tabItem {
                    Label("tab_profile", systemImage: "person.crop.circle")
                }
                .tag(AppTab.profile)
        }
        .sensoryFeedback(.selection, trigger: selectedTab)
        .task {
            await bootstrapDataIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                cardsService.cancelInFlightRequests()
                paymentsService.cancelInFlightRequests()
            case .active:
                Task {
                    async let cards: Void = cardsService.resumeOnForeground()
                    async let dashboard: Void = paymentsService.resumeOnForeground()
                    _ = await (cards, dashboard)
                }
            default:
                break
            }
        }
    }

    private func bootstrapDataIfNeeded() async {
        if !cardsService.hasLoaded {
            async let cards: Void = cardsService.fetchCards()
            async let dashboard: Void = paymentsService.fetchDashboard()
            _ = await (cards, dashboard)
        } else if !paymentsService.hasCachedDashboard {
            await paymentsService.fetchDashboard()
        }
    }
}

#Preview {
    ContentView()
        .environment(CardsAPIService())
        .environment(PaymentsAPIService())
}
