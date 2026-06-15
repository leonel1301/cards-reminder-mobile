import Foundation

struct APIOwner: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    let userID: UUID
    let name: String
    let salaryDay: Int?
    let isSelf: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case name
        case salaryDay = "salary_day"
        case isSelf = "is_self"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateOwnerRequest: Encodable, Sendable {
    let name: String
    let salaryDay: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case salaryDay = "salary_day"
    }
}

struct UpdateOwnerRequest: Encodable, Sendable {
    var name: String?
    var salaryDay: Int?

    enum CodingKeys: String, CodingKey {
        case name
        case salaryDay = "salary_day"
    }
}

extension APIOwner {
    var displayName: String {
        if isSelf {
            return String(format: String(localized: "owner_self_format"), name)
        }
        return name
    }

    var salaryDayLabel: String {
        guard let salaryDay else {
            return String(localized: "value_not_available")
        }
        return String(format: String(localized: "owner_salary_day_value"), salaryDay)
    }
}
