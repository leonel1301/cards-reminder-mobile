import SwiftUI

struct SplashView: View {
    var onFinish: () -> Void

    @State private var logoScale: CGFloat = 0.85
    @State private var logoOpacity: Double = 0
    @State private var titleOpacity: Double = 0

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.primaryAction.opacity(0.12))
                        .frame(width: 120, height: 120)

                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(Color.primaryAction)
                        .symbolEffect(.pulse, options: .repeating)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)

                VStack(spacing: 8) {
                    Text("app_name")
                        .font(.title.bold())
                        .foregroundStyle(.primary)

                    Text("app_tagline")
                        .font(.subheadline)
                        .foregroundStyle(Color.secondaryText)
                }
                .opacity(titleOpacity)

                ProgressView()
                    .tint(Color.primaryAction)
                    .padding(.top, 32)
                    .opacity(titleOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75)) {
                logoScale = 1
                logoOpacity = 1
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.25)) {
                titleOpacity = 1
            }

            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeInOut(duration: 0.35)) {
                    onFinish()
                }
            }
        }
    }
}

#Preview {
    SplashView(onFinish: {})
}
