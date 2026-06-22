import Foundation

struct APIFeedback: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let userID: UUID
    let title: String
    let device: String
    let content: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case title
        case device
        case content
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateFeedbackRequest: Encodable, Sendable {
    let title: String
    let device: String
    let content: String
}

struct UpdateFeedbackRequest: Encodable, Sendable {
    var title: String?
    var device: String?
    var content: String?

    enum CodingKeys: String, CodingKey {
        case title
        case device
        case content
    }
}
