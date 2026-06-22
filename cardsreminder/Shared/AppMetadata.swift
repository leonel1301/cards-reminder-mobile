import Foundation

enum AppMetadata {
    static let faqURL = URL(string: "https://lenaralabs.com/apps/waloop/faq")!
    static let feedbackURL = URL(string: "https://lenaralabs.com/apps/waloop/feedback")!
    static let privacyURL = URL(string: "https://lenaralabs.com/apps/waloop/privacy")!
    static let termsURL = URL(string: "https://lenaralabs.com/apps/waloop/terms")!

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}
