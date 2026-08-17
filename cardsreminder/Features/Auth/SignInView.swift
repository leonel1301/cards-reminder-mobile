import FirebaseAnalytics
import SwiftUI

private struct SignInPressButtonStyle: ButtonStyle {
    var reduceMotion: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.97)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @State private var headerVisible = false
    @State private var contentVisible = false
    @State private var footerVisible = false

    private var motion: Animation? {
        SmoothRevealAnimation.motion(reduceMotion: reduceMotion)
    }

    private var isAppleLoading: Bool {
        authManager.activeSignInMethod == .apple
    }

    private var isGoogleLoading: Bool {
        authManager.activeSignInMethod == .google
    }

    var body: some View {
        ZStack {
            background

            ViewThatFits(in: .vertical) {
                fullHeightLayout
                compactScrollLayout
            }
        }
        .onAppear {
            runEntranceAnimation()
        }
        .analyticsScreen(name: "Sign In")
    }

    private var fullHeightLayout: some View {
        VStack(spacing: 0) {
            header
                .padding(.top, 48)
                .offset(y: headerVisible ? 0 : 20)
                .opacity(headerVisible ? 1 : 0)

            Spacer(minLength: 48)

            bottomCluster
        }
        .frame(maxWidth: 420)
        .frame(maxWidth: .infinity)
    }

    private var compactScrollLayout: some View {
        ScrollView {
            VStack(spacing: 48) {
                header
                    .padding(.top, 36)
                    .offset(y: headerVisible ? 0 : 20)
                    .opacity(headerVisible ? 1 : 0)

                bottomCluster
            }
            .frame(maxWidth: 420)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
    }

    private var bottomCluster: some View {
        VStack(spacing: 20) {
            signInSection
                .offset(y: contentVisible ? 0 : 16)
                .opacity(contentVisible ? 1 : 0)

            PoweredByLenaraFooter()
                .opacity(footerVisible ? 1 : 0)
                .padding(.bottom, 24)
        }
    }

    private var background: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            Circle()
                .fill(Color.primaryAction.opacity(0.1))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -80, y: -220)

            Circle()
                .fill(Color.headerSurface.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 55)
                .offset(x: 100, y: 280)
        }
        .accessibilityHidden(true)
    }

    private var header: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.primaryAction.opacity(0.12))
                    .frame(width: 120, height: 120)

                Image(systemName: "creditcard.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.primaryAction)
            }
            .accessibilityHidden(true)

            VStack(spacing: 8) {
                Text("app_name")
                    .font(.title.bold())
                    .foregroundStyle(.primary)

                Text("sign_in_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    private var signInSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("sign_in_prompt")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text("sign_in_choose_method")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage = authManager.errorMessage {
                errorBanner(errorMessage)
            }

            VStack(spacing: 12) {
                appleButton
                googleButton
            }
        }
        .padding(.horizontal, 24)
        .animation(motion, value: authManager.errorMessage)
        .animation(motion, value: authManager.activeSignInMethod)
    }

    private var appleButton: some View {
        Button {
            Haptics.mediumImpact()
            authManager.signInWithApple()
        } label: {
            providerLabel(
                title: "sign_in_continue_apple",
                isLoading: isAppleLoading,
                spinnerTint: appleForeground
            ) {
                Image(systemName: "apple.logo")
                    .font(.title3.weight(.medium))
            }
            .foregroundStyle(appleForeground)
            .providerButtonChrome(fill: appleBackground)
        }
        .buttonStyle(SignInPressButtonStyle(reduceMotion: reduceMotion))
        .disabled(authManager.isLoading && !isAppleLoading)
        .opacity(authManager.isLoading && !isAppleLoading ? 0.45 : 1)
        .accessibilityLabel(Text("sign_in_continue_apple"))
        .accessibilityValue(isAppleLoading ? Text("sign_in_loading") : Text(verbatim: ""))
    }

    private var googleButton: some View {
        Button {
            Haptics.mediumImpact()
            Task {
                await authManager.signInWithGoogle()
            }
        } label: {
            providerLabel(
                title: "sign_in_continue_google",
                isLoading: isGoogleLoading,
                spinnerTint: Color.primaryAction
            ) {
                Image("GoogleG")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 20, height: 20)
                    .scaleEffect(1.28)
                    .clipped()
                    .accessibilityHidden(true)
            }
            .foregroundStyle(.primary)
            .providerButtonChrome(fill: Color.cardSurface, stroke: Color.defaultBorder.opacity(0.55))
        }
        .buttonStyle(SignInPressButtonStyle(reduceMotion: reduceMotion))
        .disabled(authManager.isLoading && !isGoogleLoading)
        .opacity(authManager.isLoading && !isGoogleLoading ? 0.45 : 1)
        .accessibilityLabel(Text("sign_in_continue_google"))
        .accessibilityValue(isGoogleLoading ? Text("sign_in_loading") : Text(verbatim: ""))
    }

    private func providerLabel<Icon: View>(
        title: LocalizedStringKey,
        isLoading: Bool,
        spinnerTint: Color,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .controlSize(.regular)
                    .tint(spinnerTint)
            } else {
                icon()
            }

            Text(isLoading ? LocalizedStringKey("sign_in_loading") : title)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(minHeight: 54)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.amberStateForeground)

            Text(message)
                .font(.caption)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(
            Color.amberStateBackground.opacity(0.6),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .accessibilityElement(children: .combine)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private var appleBackground: Color {
        colorScheme == .dark ? .white : .black
    }

    private var appleForeground: Color {
        colorScheme == .dark ? .black : .white
    }

    private func runEntranceAnimation() {
        if reduceMotion {
            headerVisible = true
            contentVisible = true
            footerVisible = true
            return
        }

        withAnimation(.spring(response: 0.68, dampingFraction: 0.82)) {
            headerVisible = true
        }

        withAnimation(.spring(response: 0.68, dampingFraction: 0.82).delay(0.14)) {
            contentVisible = true
        }

        withAnimation(.easeOut(duration: 0.45).delay(0.32)) {
            footerVisible = true
        }
    }
}

private extension View {
    func providerButtonChrome(fill: Color, stroke: Color? = nil) -> some View {
        background(fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                if let stroke {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(stroke, lineWidth: 1)
                }
            }
    }
}

#Preview {
    SignInView()
        .environment(AuthManager())
}
