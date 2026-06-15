import Foundation

struct APIDevice: Codable, Sendable {
    let id: UUID
    let userID: UUID
    let fcmToken: String
    let platform: String
    let language: String
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case fcmToken = "fcm_token"
        case platform
        case language
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct RegisterDeviceRequest: Encodable, Sendable {
    let fcmToken: String
    let platform: String
    let language: String

    enum CodingKeys: String, CodingKey {
        case fcmToken = "fcm_token"
        case platform
        case language
    }
}

struct UnregisterDeviceRequest: Encodable, Sendable {
    let fcmToken: String

    enum CodingKeys: String, CodingKey {
        case fcmToken = "fcm_token"
    }
}
