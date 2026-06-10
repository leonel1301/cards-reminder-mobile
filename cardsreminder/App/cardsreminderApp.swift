//
//  cardsreminderApp.swift
//  cardsreminder
//
//  Created by Leonel Ortega on 8/06/26.
//

import FirebaseCore
import GoogleSignIn
import SwiftData
import SwiftUI

@main
struct cardsreminderApp: App {
    @State private var authManager: AuthManager

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
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
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
