import SwiftUI

private struct SignInPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager

    @State private var headerVisible = false
    @State private var contentVisible = false
    @State private var footerVisible = false
    @State private var logoBreathing = false

    var body: some View {
        ZStack {
            background

            VStack(spacing: 0) {
                header
                    .offset(y: headerVisible ? 0 : 28)
                    .opacity(headerVisible ? 1 : 0)

                Spacer(minLength: 28)

                signInSection
                    .offset(y: contentVisible ? 0 : 22)
                    .opacity(contentVisible ? 1 : 0)

                Spacer(minLength: 28)

                PoweredByLenaraFooter()
                    .opacity(footerVisible ? 1 : 0)
                    .padding(.bottom, 24)
            }

            if authManager.isLoading {
                loadingOverlay
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: authManager.isLoading)
        .onAppear {
            runEntranceAnimation()
        }
    }

    private var background: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            Circle()
                .fill(Color.headerSurface.opacity(0.22))
                .frame(width: 320, height: 320)
                .blur(radius: 70)
                .offset(x: -90, y: -260)

            Circle()
                .fill(Color.primaryAction.opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 60)
                .offset(x: 120, y: 320)
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 88, height: 88)
                    .scaleEffect(logoBreathing ? 1.04 : 0.96)

                Image(systemName: "creditcard.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.white)
                    .symbolEffect(.pulse, options: .repeating.speed(0.35))
            }

            VStack(spacing: 8) {
                Text("app_name")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                Text("sign_in_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 36)
        .padding(.bottom, 28)
        .padding(.horizontal, 24)
        .background(Color.headerSurface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: Color.headerSurface.opacity(0.35), radius: 24, y: 12)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var signInSection: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Text("sign_in_prompt")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("sign_in_choose_method")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage = authManager.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(Color.redStateForeground)

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.redStateForeground)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color.redStateBackground.opacity(0.65))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            VStack(spacing: 12) {
                Button {
                    authManager.signInWithApple()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 20, weight: .medium))

                        Text("sign_in_continue_apple")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(SignInPressButtonStyle())
                .disabled(authManager.isLoading)

                Button {
                    Task {
                        await authManager.signInWithGoogle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image("GoogleG")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .scaleEffect(1.4)
                            .clipped()

                        Text("sign_in_continue_google")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.cardSurface)
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.defaultBorder.opacity(0.55), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(SignInPressButtonStyle())
                .disabled(authManager.isLoading)
            }
        }
        .padding(.horizontal, 24)
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: authManager.errorMessage)
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.18)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(Color.primaryAction)

                Text("sign_in_loading")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 22)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func runEntranceAnimation() {
        withAnimation(.spring(response: 0.68, dampingFraction: 0.82)) {
            headerVisible = true
        }

        withAnimation(.spring(response: 0.68, dampingFraction: 0.82).delay(0.14)) {
            contentVisible = true
        }

        withAnimation(.easeOut(duration: 0.45).delay(0.32)) {
            footerVisible = true
        }

        withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
            logoBreathing = true
        }
    }
}

#Preview {
    SignInView()
        .environment(AuthManager())
}
