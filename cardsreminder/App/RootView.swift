import SwiftUI

struct RootView: View {
    @Environment(AuthManager.self) private var authManager
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var showSplash = true

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
                ContentView()
                    .transition(.opacity)
            } else {
                SignInView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showSplash)
        .animation(.easeInOut(duration: 0.35), value: hasCompletedOnboarding)
        .animation(.easeInOut(duration: 0.35), value: authManager.isSignedIn)
    }
}

#Preview {
    RootView()
        .environment(AuthManager())
}
