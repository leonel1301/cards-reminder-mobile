import SwiftUI

struct OnboardingPage: Identifiable {
    let id = UUID()
    let icon: String
    let iconBackground: Color
    let iconForeground: Color
    let title: String
    let subtitle: String
}

extension OnboardingPage {
    static let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "creditcard.fill",
            iconBackground: Color.primaryAction.opacity(0.15),
            iconForeground: .primaryAction,
            title: String(localized: "onboarding_welcome_title"),
            subtitle: String(localized: "onboarding_welcome_subtitle")
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            iconBackground: Color.redStateBackground,
            iconForeground: .redStateForeground,
            title: String(localized: "onboarding_reminders_title"),
            subtitle: String(localized: "onboarding_reminders_subtitle")
        ),
        OnboardingPage(
            icon: "calendar.badge.clock",
            iconBackground: Color.violetStateBackground,
            iconForeground: .violetStateForeground,
            title: String(localized: "onboarding_optimal_title"),
            subtitle: String(localized: "onboarding_optimal_subtitle")
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            iconBackground: Color.emeraldStateBackground,
            iconForeground: .emeraldStateForeground,
            title: String(localized: "onboarding_status_title"),
            subtitle: String(localized: "onboarding_status_subtitle")
        ),
    ]
}
