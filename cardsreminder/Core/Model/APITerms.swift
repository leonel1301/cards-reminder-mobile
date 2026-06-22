import Foundation

struct APITerms: Codable, Sendable {
    let termsVersion: String

    enum CodingKeys: String, CodingKey {
        case termsVersion = "terms_version"
    }
}
