import FirebaseAnalytics
import SwiftUI
import UIKit

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(CardsAPIService.self) private var cardsService
    @Environment(PaymentsAPIService.self) private var paymentsService

    @State private var navigation = AppNavigation()

    private var timelineTabIcon: String {
        colorScheme == .dark ? "moon.fill" : "sun.max.fill"
    }

    var body: some View {
        @Bindable var navigation = navigation

        TabView(selection: $navigation.selectedTab) {
            TimelineView()
                .tabItem {
                    Image(systemName: timelineTabIcon)
                }
                .accessibilityLabel("tab_timeline")
                .tag(AppTab.timeline)

            CalendarView()
                .tabItem {
                    Image(systemName: "calendar")
                }
                .accessibilityLabel("tab_calendar")
                .tag(AppTab.calendar)

            CardsView()
                .tabItem {
                    Image(systemName: "creditcard")
                }
                .accessibilityLabel("tab_cards")
                .tag(AppTab.cards)

            ProfileView()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                }
                .accessibilityLabel("tab_profile")
                .tag(AppTab.profile)

            GardenView()
                .tabItem {
                    thingsTabIcon
                }
                .accessibilityLabel("tab_garden")
                .tag(AppTab.garden)
        }
        .environment(navigation)
        .sensoryFeedback(.selection, trigger: navigation.selectedTab)
        .analyticsScreen(name: navigation.selectedTab.analyticsName)
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
        .sheet(isPresented: $navigation.showCreateCard, onDismiss: {
            Task { await refreshAfterCardChange() }
        }) {
            CardFormView(mode: .create)
        }
        .sheet(isPresented: $navigation.showLearn) {
            NavigationStack {
                LearnHubView(showsCloseButton: true)
            }
        }
    }

    private var thingsTabIcon: Image {
        let symbolName = "leaf.fill"
        let config = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let green = UIColor(red: 0.24, green: 0.72, blue: 0.34, alpha: 1)
        guard let symbol = UIImage(systemName: symbolName, withConfiguration: config) else {
            return Image(systemName: symbolName)
        }
        return Image(uiImage: symbol.withTintColor(green, renderingMode: .alwaysOriginal))
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

    private func refreshAfterCardChange() async {
        async let cards: Void = cardsService.fetchCards(silentUnlessEmpty: false)
        async let dashboard: Void = paymentsService.fetchDashboard(silentUnlessEmpty: false)
        _ = await (cards, dashboard)
    }
}

#Preview {
    ContentView()
        .environment(CardsAPIService())
        .environment(PaymentsAPIService())
}
