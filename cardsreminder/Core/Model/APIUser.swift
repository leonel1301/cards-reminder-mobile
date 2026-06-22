import Foundation

struct APIUser: Codable, Sendable {
    let id: UUID
    let firebaseUID: String
    let email: String?
    let displayName: String?
    let termsAcceptedAt: Date?
    let privacyAcceptedAt: Date?
    let termsVersion: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case firebaseUID = "firebase_uid"
        case email
        case displayName = "display_name"
        case termsAcceptedAt = "terms_accepted_at"
        case privacyAcceptedAt = "privacy_accepted_at"
        case termsVersion = "terms_version"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    func hasAcceptedTerms(requiredVersion: String) -> Bool {
        guard termsAcceptedAt != nil, privacyAcceptedAt != nil else { return false }
        guard let termsVersion, termsVersion == requiredVersion else { return false }
        return true
    }
}
