import Foundation
import SwiftUI

enum CardsSortOrder: String, CaseIterable, Identifiable, Hashable, Sendable {
    case urgency
    case name
    case paymentDay

    var id: String { rawValue }

    var labelKey: LocalizedStringKey {
        switch self {
        case .urgency: "cards_sort_urgency"
        case .name: "cards_sort_name"
        case .paymentDay: "cards_sort_payment_day"
        }
    }
}

enum CardsStatusFilter: Hashable, Sendable {
    case all
    case kind(CardPaymentStatusKind)
}

struct CardsListQuery: Equatable, Sendable {
    var searchText: String = ""
    var statusFilter: CardsStatusFilter = .all
    var ownerID: UUID?
    var sortOrder: CardsSortOrder = .urgency

    var isRefined: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || statusFilter != .all
            || ownerID != nil
    }

    mutating func clearRefinements() {
        searchText = ""
        statusFilter = .all
        ownerID = nil
    }
}

enum CardsListArrangement {
    /// Ordered list of status kinds, from the one that needs attention first to the one that needs none.
    nonisolated static let urgencyOrder: [CardPaymentStatusKind] = [
        .overdue, .urgent, .dueSoon, .optimalDay, .onTrack, .paid,
    ]

    nonisolated static func apply(
        _ query: CardsListQuery,
        to cards: [APICard],
        status: (UUID) -> APICardStatus?
    ) -> [APICard] {
        let needle = query.searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        let filtered = cards.filter { card in
            if let ownerID = query.ownerID, card.ownerID != ownerID {
                return false
            }

            if case .kind(let kind) = query.statusFilter, status(card.id)?.kind != kind {
                return false
            }

            guard !needle.isEmpty else { return true }

            return card.name.lowercased().contains(needle)
                || card.issuer?.lowercased().contains(needle) == true
                || card.lastFourDigits.contains(needle)
        }

        return filtered.sorted { lhs, rhs in
            switch query.sortOrder {
            case .name:
                return isBeforeByName(lhs, rhs)

            case .paymentDay:
                guard lhs.paymentDueDay == rhs.paymentDueDay else {
                    return lhs.paymentDueDay < rhs.paymentDueDay
                }
                return isBeforeByName(lhs, rhs)

            case .urgency:
                let lhsStatus = status(lhs.id)
                let rhsStatus = status(rhs.id)

                let lhsRank = urgencyRank(for: lhsStatus)
                let rhsRank = urgencyRank(for: rhsStatus)
                guard lhsRank == rhsRank else { return lhsRank < rhsRank }

                let lhsDays = lhsStatus.map(signedRemainingDays) ?? .max
                let rhsDays = rhsStatus.map(signedRemainingDays) ?? .max
                guard lhsDays == rhsDays else { return lhsDays < rhsDays }

                return isBeforeByName(lhs, rhs)
            }
        }
    }

    nonisolated static func statusCounts(
        for cards: [APICard],
        status: (UUID) -> APICardStatus?
    ) -> [CardPaymentStatusKind: Int] {
        cards.reduce(into: [:]) { counts, card in
            guard let kind = status(card.id)?.kind else { return }
            counts[kind, default: 0] += 1
        }
    }

    nonisolated static func urgencyRank(for status: APICardStatus?) -> Int {
        guard let kind = status?.kind, let rank = urgencyOrder.firstIndex(of: kind) else {
            return urgencyOrder.count
        }
        return rank
    }

    /// Negative while the payment is late, so overdue cards sort ahead of upcoming ones.
    nonisolated private static func signedRemainingDays(_ status: APICardStatus) -> Int {
        status.daysOverdue > 0 ? -status.daysOverdue : status.daysUntilPayment
    }

    nonisolated private static func isBeforeByName(_ lhs: APICard, _ rhs: APICard) -> Bool {
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
