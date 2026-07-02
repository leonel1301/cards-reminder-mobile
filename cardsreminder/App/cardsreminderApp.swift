//
//  cardsreminderApp.swift
//  cardsreminder
//
//  Created by Leonel Ortega on 8/06/26.
//

import FirebaseAnalytics
import FirebaseCore
import GoogleSignIn
import SwiftData
import SwiftUI

@main
struct cardsreminderApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var authManager: AuthManager
    @State private var pushNotificationManager = PushNotificationManager.shared
    @State private var cardsService = CardsAPIService()
    @State private var userService = UserAPIService()
    @State private var ownersService = OwnersAPIService()
    @State private var feedbackService = FeedbackAPIService()
    @State private var paymentsService = PaymentsAPIService()
    @State private var appearanceManager = AppearanceManager.shared

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([UserProfile.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        FirebaseApp.configure()

        if let clientID = FirebaseApp.app()?.options.clientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        }

        _authManager = State(initialValue: AuthManager())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(authManager)
                .environment(cardsService)
                .environment(userService)
                .environment(ownersService)
                .environment(feedbackService)
                .environment(paymentsService)
                .environment(pushNotificationManager)
                .environment(appearanceManager)
                .preferredColorScheme(appearanceManager.appearance.colorScheme)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
