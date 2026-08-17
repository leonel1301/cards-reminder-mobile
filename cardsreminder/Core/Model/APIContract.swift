import Foundation

struct ContractExtraction: Decodable, Sendable, Hashable {
    let name: String?
    let lastFourDigits: String?
    let issuer: String?
    let billingCycleDay: Int?
    let paymentDueDay: Int?
    let annualFee: String?
    let interestRateSummary: String?
    let notes: String?
    let summary: String
    let confidence: String
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case name
        case lastFourDigits = "last_four_digits"
        case issuer
        case billingCycleDay = "billing_cycle_day"
        case paymentDueDay = "payment_due_day"
        case annualFee = "annual_fee"
        case interestRateSummary = "interest_rate_summary"
        case notes
        case summary
        case confidence
        case warnings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        lastFourDigits = try container.decodeIfPresent(String.self, forKey: .lastFourDigits)
        issuer = try container.decodeIfPresent(String.self, forKey: .issuer)
        billingCycleDay = try container.decodeIfPresent(Int.self, forKey: .billingCycleDay)
        paymentDueDay = try container.decodeIfPresent(Int.self, forKey: .paymentDueDay)
        annualFee = try container.decodeIfPresent(String.self, forKey: .annualFee)
        interestRateSummary = try container.decodeIfPresent(String.self, forKey: .interestRateSummary)
        notes = try container.decodeIfPresent(String.self, forKey: .notes)
        summary = try container.decode(String.self, forKey: .summary)
        confidence = try container.decode(String.self, forKey: .confidence)
        warnings = try container.decodeIfPresent([String].self, forKey: .warnings) ?? []
    }
}

struct ContractUsage: Codable, Sendable, Equatable {
    let used: Int
    let limit: Int
    let remaining: Int

    static let betaLimit = 5
}
