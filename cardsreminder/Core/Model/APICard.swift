import Foundation
import SwiftUI

struct APICard: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let userID: UUID
    let ownerID: UUID
    let name: String
    let lastFourDigits: String
    let issuer: String?
    let billingCycleDay: Int
    let paymentDueDay: Int
    let colorHex: String?
    let notes: String?
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case ownerID = "owner_id"
        case name
        case lastFourDigits = "last_four_digits"
        case issuer
        case billingCycleDay = "billing_cycle_day"
        case paymentDueDay = "payment_due_day"
        case colorHex = "color_hex"
        case notes
        case isActive = "is_active"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CreateCardRequest: Encodable, Sendable {
    let name: String
    let lastFourDigits: String
    let issuer: String?
    let billingCycleDay: Int
    let paymentDueDay: Int
    let colorHex: String?
    let notes: String?
    let ownerID: UUID?

    enum CodingKeys: String, CodingKey {
        case name
        case lastFourDigits = "last_four_digits"
        case issuer
        case billingCycleDay = "billing_cycle_day"
        case paymentDueDay = "payment_due_day"
        case colorHex = "color_hex"
        case notes
        case ownerID = "owner_id"
    }
}

struct UpdateCardRequest: Encodable, Sendable {
    var name: String?
    var lastFourDigits: String?
    var issuer: String?
    var billingCycleDay: Int?
    var paymentDueDay: Int?
    var colorHex: String?
    var notes: String?
    var isActive: Bool?
    var ownerID: UUID?

    enum CodingKeys: String, CodingKey {
        case name
        case lastFourDigits = "last_four_digits"
        case issuer
        case billingCycleDay = "billing_cycle_day"
        case paymentDueDay = "payment_due_day"
        case colorHex = "color_hex"
        case notes
        case isActive = "is_active"
        case ownerID = "owner_id"
    }
}

extension APICard {
    var periodEndDay: Int { billingCycleDay }

    var periodStartDay: Int {
        billingCycleDay >= 31 ? 1 : billingCycleDay + 1
    }

    var paymentDay: Int { paymentDueDay }

    var displayColorHex: String {
        let raw = colorHex ?? "808080"
        return raw.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    }

    var color: Color { Color(hex: displayColorHex) }

    var maskedNumber: String {
        guard lastFourDigits != "0000" else { return "•••• ••••" }
        return "•••• \(lastFourDigits)"
    }
}
