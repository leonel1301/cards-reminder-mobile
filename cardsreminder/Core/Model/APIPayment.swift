import Foundation

struct APIPayment: Codable, Identifiable, Sendable {
    let id: UUID
    let cardID: UUID
    let cycleEnd: Date
    let paidAt: Date
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id
        case cardID = "card_id"
        case cycleEnd = "cycle_end"
        case paidAt = "paid_at"
        case notes
    }
}

struct APICardStatus: Codable, Sendable, Equatable {
    let status: String
    let cycleStart: Date
    let cycleEnd: Date
    let paymentDueDate: Date
    let daysUntilPayment: Int
    let daysOverdue: Int
    let optimalPurchaseDay: Int
    let isOptimalPurchaseDay: Bool
    let isPaidThisCycle: Bool

    enum CodingKeys: String, CodingKey {
        case status
        case cycleStart = "cycle_start"
        case cycleEnd = "cycle_end"
        case paymentDueDate = "payment_due_date"
        case daysUntilPayment = "days_until_payment"
        case daysOverdue = "days_overdue"
        case optimalPurchaseDay = "optimal_purchase_day"
        case isOptimalPurchaseDay = "is_optimal_purchase_day"
        case isPaidThisCycle = "is_paid_this_cycle"
    }
}

struct CardPaymentsResponse: Codable, Sendable {
    let card: APICard
    let payments: [APIPayment]
}

struct MarkPaidRequest: Encodable, Sendable {
    let notes: String?
}

struct MarkPaidResponse: Codable, Sendable {
    let card: APICard
    let status: APICardStatus
    let optimalPurchaseDays: [Date]

    enum CodingKeys: String, CodingKey {
        case card
        case status
        case optimalPurchaseDays = "optimal_purchase_days"
    }
}

struct APICardCycle: Codable, Sendable, Equatable {
    let start: Date
    let end: Date
    let paymentDue: Date

    enum CodingKeys: String, CodingKey {
        case start, end
        case paymentDue = "payment_due"
    }
}

struct CardStatusResponse: Codable, Sendable {
    let card: APICard
    let status: APICardStatus
    let optimalPurchaseDays: [Date]

    enum CodingKeys: String, CodingKey {
        case card
        case status
        case optimalPurchaseDays = "optimal_purchase_days"
    }
}

struct CurrentCycleResponse: Codable, Sendable {
    let card: APICard
    let cycle: APICardCycle
    let status: APICardStatus
}

struct OptimalPurchaseDaysResponse: Codable, Sendable {
    let card: APICard
    let cycle: APICardCycle
    let optimalPurchaseDays: [Date]

    enum CodingKeys: String, CodingKey {
        case card, cycle
        case optimalPurchaseDays = "optimal_purchase_days"
    }
}

struct DashboardCardEntry: Codable, Sendable {
    let card: APICard
    let status: APICardStatus
}

struct BestForPurchase: Codable, Sendable, Equatable {
    let cardID: UUID
    let why: String

    enum CodingKeys: String, CodingKey {
        case cardID = "card_id"
        case why
    }
}

struct DashboardSummary: Codable, Sendable, Equatable {
    let total: Int
    let overdue: Int
    let urgent: Int
    let dueSoon: Int
    let paid: Int
    let optimalDay: Int
    let onTrack: Int

    enum CodingKeys: String, CodingKey {
        case total
        case overdue
        case urgent
        case dueSoon = "due_soon"
        case paid
        case optimalDay = "optimal_day"
        case onTrack = "on_track"
    }

    var hasAttentionItems: Bool {
        overdue > 0 || urgent > 0 || dueSoon > 0
    }
}

struct DashboardResponse: Codable, Sendable {
    let cards: [DashboardCardEntry]
    let summary: DashboardSummary
    let bestForPurchase: BestForPurchase?

    enum CodingKeys: String, CodingKey {
        case cards, summary
        case bestForPurchase = "best_for_purchase"
    }
}

enum CardPaymentStatusKind: String, Sendable {
    case paid
    case overdue
    case urgent
    case dueSoon = "due_soon"
    case optimalDay = "optimal_day"
    case onTrack = "on_track"

    init(rawStatus: String) {
        self = CardPaymentStatusKind(rawValue: rawStatus) ?? .onTrack
    }
}

extension APICardStatus {
    var kind: CardPaymentStatusKind {
        CardPaymentStatusKind(rawStatus: status)
    }
}
