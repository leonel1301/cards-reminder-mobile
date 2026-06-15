import Foundation

struct APIUser: Codable, Sendable {
    let id: UUID
    let firebaseUID: String
    let email: String?
    let displayName: String?
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case firebaseUID = "firebase_uid"
        case email
        case displayName = "display_name"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}
