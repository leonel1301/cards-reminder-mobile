import Foundation

enum PaymentConfirmationCopy {
    /// Names the cycle being settled, so a one-tap payment says what it covers.
    static func message(for status: APICardStatus?) -> String {
        guard let status else {
            return String(localized: "payments_quick_confirm_message_fallback")
        }

        let start = status.cycleStart.formatted(date: .abbreviated, time: .omitted)
        let end = status.cycleEnd.formatted(date: .abbreviated, time: .omitted)

        return String(
            format: String(localized: "payments_quick_confirm_message"),
            "\(start) – \(end)"
        )
    }
}
