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
            title: "Bienvenido a CardsReminder",
            subtitle: "Organiza todas tus tarjetas de crédito en un solo lugar y mantén el control de tus finanzas."
        ),
        OnboardingPage(
            icon: "bell.badge.fill",
            iconBackground: Color.redStateBackground,
            iconForeground: .redStateForeground,
            title: "Nunca pierdas un vencimiento",
            subtitle: "Recibe alertas claras cuando una tarjeta esté por vencer o requiera pago urgente."
        ),
        OnboardingPage(
            icon: "calendar.badge.clock",
            iconBackground: Color.violetStateBackground,
            iconForeground: .violetStateForeground,
            title: "Compra en el mejor día",
            subtitle: "Descubre el día óptimo para usar cada tarjeta y aprovecha al máximo tu ciclo de facturación."
        ),
        OnboardingPage(
            icon: "checkmark.seal.fill",
            iconBackground: Color.emeraldStateBackground,
            iconForeground: .emeraldStateForeground,
            title: "Todo al día, sin estrés",
            subtitle: "Visualiza el estado de cada tarjeta de un vistazo: pagada, pendiente o próxima a vencer."
        ),
    ]
}
