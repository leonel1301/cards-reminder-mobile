import FirebaseAnalytics
import SwiftUI

struct PostLoginSetupView: View {
    @Environment(\.openURL) private var openURL
    @Environment(UserAPIService.self) private var userService

    @State private var messageIndex = 0
    @State private var messageVisible = false
    @State private var actionsVisible = false
    @State private var isSubmitting = false
    @State private var presentedSafariURL: PresentedURL?

    private let welcomeMessageKeys = [
        "post_login_welcome_excited",
        "post_login_welcome_ready",
    ]

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                Spacer()

                welcomeMessage
                    .padding(.horizontal, 28)

                Spacer()

                VStack(spacing: 20) {
                    continueButton

                    if let errorMessage = userService.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color.redStateForeground)
                            .multilineTextAlignment(.center)
                    }

                    termsFooter
                }
                .padding(.horizontal, 24)
                .opacity(actionsVisible ? 1 : 0)
                .offset(y: actionsVisible ? 0 : 16)

                PoweredByLenaraFooter()
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    .opacity(actionsVisible ? 1 : 0)
            }

            if isSubmitting {
                submittingOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isSubmitting)
        .onAppear {
            runEntranceAnimation()
        }
        .inAppSafariSheet(presentedURL: $presentedSafariURL)
        .analyticsScreen(name: "Post Login Setup")
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
    }

    private var welcomeMessage: some View {
        Text(LocalizedStringKey(welcomeMessageKeys[messageIndex]))
            .font(.system(size: 34, weight: .bold))
            .foregroundStyle(.primary)
            .multilineTextAlignment(.center)
            .lineSpacing(6)
            .opacity(messageVisible ? 1 : 0)
            .offset(y: messageVisible ? 0 : 12)
            .animation(.easeInOut(duration: 0.55), value: messageIndex)
            .animation(.easeOut(duration: 0.6), value: messageVisible)
            .id(messageIndex)
    }

    private var continueButton: some View {
        Button {
            Haptics.mediumImpact()
            Task { await submitAcceptance() }
        } label: {
            Text("action_continue")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.primaryAction)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PostLoginPressButtonStyle())
        .disabled(isSubmitting)
    }

    private var submittingOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            ProgressView()
                .controlSize(.large)
                .tint(Color.primaryAction)
        }
    }

    private var termsFooter: some View {
        Text(termsAttributedString)
            .font(.caption)
            .foregroundStyle(Color.secondaryText)
            .multilineTextAlignment(.center)
            .tint(Color.primaryAction)
            .environment(\.openURL, OpenURLAction { url in
                AppLink.open(url, presentingIn: $presentedSafariURL, openURL: openURL)
                return .handled
            })
    }

    private var termsAttributedString: AttributedString {
        var result = AttributedString(String(localized: "post_login_terms_prefix"))

        var terms = AttributedString(String(localized: "post_login_terms_link"))
        terms.link = AppMetadata.termsURL
        terms.underlineStyle = .single

        var middle = AttributedString(String(localized: "post_login_terms_middle"))

        var privacy = AttributedString(String(localized: "post_login_privacy_link"))
        privacy.link = AppMetadata.privacyURL
        privacy.underlineStyle = .single

        var suffix = AttributedString(String(localized: "post_login_terms_suffix"))

        result.append(terms)
        result.append(middle)
        result.append(privacy)
        result.append(suffix)

        return result
    }

    private func submitAcceptance() async {
        guard !isSubmitting else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        _ = await userService.acceptTerms()
    }

    private func runEntranceAnimation() {
        withAnimation(.easeOut(duration: 0.65)) {
            messageVisible = true
        }

        withAnimation(.spring(response: 0.68, dampingFraction: 0.82).delay(0.35)) {
            actionsVisible = true
        }

        Task {
            try? await Task.sleep(for: .seconds(3.2))
            withAnimation(.easeInOut(duration: 0.55)) {
                messageIndex = 1
            }
        }
    }
}

private struct PostLoginPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

#Preview {
    PostLoginSetupView()
        .environment(UserAPIService())
}
