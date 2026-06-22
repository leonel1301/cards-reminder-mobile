import SwiftUI
import FirebaseAuth

struct RootView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(CardsAPIService.self) private var cardsService
    @Environment(OwnersAPIService.self) private var ownersService
    @Environment(FeedbackAPIService.self) private var feedbackService
    @Environment(PaymentsAPIService.self) private var paymentsService
    @Environment(UserAPIService.self) private var userService
    @Environment(PushNotificationManager.self) private var pushManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showSplash = true
    @State private var lastSyncedLanguage = PushNotificationManager.backendLanguageCode
    @State private var previousSignedInUID: String?

    var body: some View {
        Group {
            if showSplash {
                SplashView {
                    showSplash = false
                }
                .transition(.opacity)
            } else if !hasCompletedOnboarding {
                OnboardingView {
                    hasCompletedOnboarding = true
                }
                .transition(.opacity)
            } else if authManager.isSignedIn {
                signedInContent
            } else {
                SignInView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showSplash)
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.35), value: authManager.isSignedIn)
        .animation(.easeInOut(duration: 0.35), value: userService.contentRevision)
        .task(id: authManager.user?.uid) {
            let currentUID = authManager.user?.uid

            if currentUID == nil {
                resetUserScopedData()
                previousSignedInUID = nil
                return
            }

            let userSwitched = previousSignedInUID != nil && previousSignedInUID != currentUID
            defer { previousSignedInUID = currentUID }

            if userSwitched {
                resetUserScopedData()
            }

            await userService.refreshCurrentUser()
            await pushManager.handleUserSessionChange(userSwitched: userSwitched)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
            Task { await resyncLanguageIfNeeded() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            Task {
                if authManager.isSignedIn {
                    await userService.refreshCurrentUser()
                }
                await resyncLanguageIfNeeded()
            }
        }
        .apiErrorAlert()
    }

    @ViewBuilder
    private var signedInContent: some View {
        if !userService.hasResolvedTermsStatus {
            sessionLoadingView
                .transition(.opacity)
        } else if userService.needsTermsAcceptance {
            PostLoginSetupView()
                .transition(.opacity)
        } else {
            ContentView()
                .transition(.opacity)
        }
    }

    private var sessionLoadingView: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            ProgressView()
                .controlSize(.large)
                .tint(Color.primaryAction)
        }
    }

    private func resyncLanguageIfNeeded() async {
        guard authManager.isSignedIn else { return }

        let currentLanguage = PushNotificationManager.backendLanguageCode
        guard currentLanguage != lastSyncedLanguage else { return }

        lastSyncedLanguage = currentLanguage
        await pushManager.syncDeviceWithBackendIfNeeded()
    }

    private func resetUserScopedData() {
        APIAlertCenter.shared.dismiss()
        cardsService.resetSession()
        ownersService.resetSession()
        feedbackService.resetSession()
        paymentsService.resetSession()
        userService.resetSession()
    }
}

#Preview {
    RootView()
        .environment(AuthManager())
        .environment(CardsAPIService())
        .environment(OwnersAPIService())
        .environment(FeedbackAPIService())
        .environment(PaymentsAPIService())
        .environment(UserAPIService())
        .environment(PushNotificationManager.shared)
}
