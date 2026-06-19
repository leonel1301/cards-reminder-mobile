import SwiftUI

struct SignInView: View {
    @Environment(AuthManager.self) private var authManager

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer()

                signInSection

                Spacer()

                PoweredByLenaraFooter()
                    .padding(.bottom, 24)
            }

            if authManager.isLoading {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()

                ProgressView()
                    .controlSize(.large)
                    .tint(Color.primaryAction)
            }
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: "creditcard.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }

            VStack(spacing: 8) {
                Text("app_name")
                    .font(.title.bold())
                    .foregroundStyle(.white)

                Text("sign_in_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .padding(.bottom, 32)
        .padding(.horizontal, 24)
        .background(Color.headerSurface)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var signInSection: some View {
        VStack(spacing: 24) {
            VStack(spacing: 8) {
                Text("sign_in_prompt")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("sign_in_choose_method")
                    .font(.subheadline)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(Color.redStateForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }

            VStack(spacing: 12) {
                Button {
                    authManager.signInWithApple()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 20, weight: .medium))

                        Text("sign_in_continue_apple")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
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
                    .frame(height: 52)
                    .background(Color.cardSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(authManager.isLoading)
            }
        }
        .padding(.horizontal, 24)
    }
}

#Preview {
    SignInView()
        .environment(AuthManager())
}
