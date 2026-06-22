import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    private let pages = OnboardingPage.pages

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    if currentPage < pages.count - 1 {
                        Button("action_skip") {
                            onComplete()
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.secondaryText)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .frame(height: 44)

                TabView(selection: $currentPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: currentPage) { _, _ in
                    Haptics.selection()
                }

                pageIndicator
                    .padding(.top, 8)

                bottomActions
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)

                PoweredByLenaraFooter()
                    .padding(.bottom, 24)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(index == currentPage ? Color.primaryAction : Color.defaultBorder)
                    .frame(width: index == currentPage ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.25), value: currentPage)
            }
        }
    }

    private var bottomActions: some View {
        Button {
            if currentPage < pages.count - 1 {
                withAnimation {
                    currentPage += 1
                }
            } else {
                Haptics.mediumImpact()
                onComplete()
            }
        } label: {
            Group {
                if currentPage < pages.count - 1 {
                    Text("action_continue")
                } else {
                    Text("action_get_started")
                }
            }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.primaryAction)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.cardSurface)
                    .frame(width: 280, height: 280)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28)
                            .strokeBorder(Color.defaultBorder, lineWidth: 1)
                    )

                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(page.iconBackground)
                            .frame(width: 88, height: 88)

                        Image(systemName: page.icon)
                            .font(.system(size: 36))
                            .foregroundStyle(page.iconForeground)
                    }
                }
            }

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
            .padding(.horizontal, 32)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
