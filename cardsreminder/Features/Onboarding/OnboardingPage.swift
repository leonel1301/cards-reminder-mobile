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
            icon: "sun.max.fill",
            iconBackground: Color.amberStateBackground,
            iconForeground: .amberStateForeground,
            title: String(localized: "onboarding_today_title"),
            subtitle: String(localized: "onboarding_today_subtitle")
        ),
        OnboardingPage(
            icon: "calendar",
            iconBackground: Color.violetStateBackground,
            iconForeground: .violetStateForeground,
            title: String(localized: "onboarding_calendar_title"),
            subtitle: String(localized: "onboarding_calendar_subtitle")
        ),
        OnboardingPage(
            icon: "person.2.fill",
            iconBackground: Color.primaryAction.opacity(0.12),
            iconForeground: .primaryAction,
            title: String(localized: "onboarding_owners_title"),
            subtitle: String(localized: "onboarding_owners_subtitle")
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            iconBackground: Color.emeraldStateBackground,
            iconForeground: .emeraldStateForeground,
            title: String(localized: "onboarding_control_title"),
            subtitle: String(localized: "onboarding_control_subtitle")
        ),
    ]
}
