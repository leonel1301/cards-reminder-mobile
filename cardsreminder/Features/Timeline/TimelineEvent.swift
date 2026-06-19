import Foundation
import SwiftUI

enum TimelineEventKind: Equatable, Sendable {
    case overdue
    case paymentDueToday
    case urgent
    case dueSoon
    case optimalToday
    case cycleEndsToday
    case paid
    case onTrack
}

struct TimelineEvent: Identifiable, Equatable, Sendable {
    let id: String
    let card: APICard
    let status: APICardStatus
    let kind: TimelineEventKind
    let sortOrder: Int
}

struct TimelineSection: Identifiable, Equatable, Sendable {
    let id: String
    let titleKey: String
    let events: [TimelineEvent]
}

struct TimelineBuildResult: Equatable, Sendable {
    let sections: [TimelineSection]
}

enum TimelineEventBuilder {
    static func build(
        from entries: [DashboardCardEntry],
        excludingCardID: UUID? = nil
    ) -> TimelineBuildResult {
        let activeEntries = entries.filter(\.card.isActive)
        let events = activeEntries
            .filter { entry in
                guard let excludingCardID else { return true }
                return entry.card.id != excludingCardID
            }
            .map(makeEvent(for:))
            .sorted { $0.sortOrder < $1.sortOrder }

        let attention = events.filter {
            switch $0.kind {
            case .overdue, .paymentDueToday, .urgent, .dueSoon:
                return true
            default:
                return false
            }
        }

        let recommended = events.filter {
            switch $0.kind {
            case .optimalToday, .cycleEndsToday:
                return true
            default:
                return false
            }
        }

        let allClear = events.filter {
            switch $0.kind {
            case .paid, .onTrack:
                return true
            default:
                return false
            }
        }

        var sections: [TimelineSection] = []

        if !attention.isEmpty {
            sections.append(TimelineSection(id: "attention", titleKey: "timeline_section_attention", events: attention))
        }
        if !recommended.isEmpty {
            sections.append(TimelineSection(id: "recommended", titleKey: "timeline_section_recommended", events: recommended))
        }
        if !allClear.isEmpty {
            sections.append(TimelineSection(id: "all_clear", titleKey: "timeline_section_all_clear", events: allClear))
        }

        return TimelineBuildResult(sections: sections)
    }

    private static func makeEvent(for entry: DashboardCardEntry) -> TimelineEvent {
        let kind = resolveKind(for: entry.status)
        return TimelineEvent(
            id: "\(entry.card.id.uuidString)-\(kindIdentifier(kind))",
            card: entry.card,
            status: entry.status,
            kind: kind,
            sortOrder: sortOrder(for: kind, status: entry.status)
        )
    }

    private static func resolveKind(for status: APICardStatus) -> TimelineEventKind {
        if status.isPaidThisCycle || status.kind == .paid {
            return .paid
        }
        if status.daysOverdue > 0 || status.kind == .overdue {
            return .overdue
        }
        if status.daysUntilPayment == 0 {
            return .paymentDueToday
        }
        if status.kind == .urgent {
            return .urgent
        }
        if status.kind == .dueSoon {
            return .dueSoon
        }
        if status.isOptimalPurchaseDay || status.kind == .optimalDay {
            return .optimalToday
        }
        if Calendar.current.isDateInToday(status.cycleEnd) {
            return .cycleEndsToday
        }
        return .onTrack
    }

    private static func sortOrder(for kind: TimelineEventKind, status: APICardStatus) -> Int {
        switch kind {
        case .overdue:
            return 0_000 - status.daysOverdue
        case .paymentDueToday:
            return 1_000
        case .urgent:
            return 2_000 + status.daysUntilPayment
        case .dueSoon:
            return 3_000 + status.daysUntilPayment
        case .optimalToday:
            return 4_000 - status.daysUntilPayment
        case .cycleEndsToday:
            return 5_000
        case .paid:
            return 8_000
        case .onTrack:
            return 9_000 + status.daysUntilPayment
        }
    }

    private static func kindIdentifier(_ kind: TimelineEventKind) -> String {
        switch kind {
        case .overdue: "overdue"
        case .paymentDueToday: "payment_due_today"
        case .urgent: "urgent"
        case .dueSoon: "due_soon"
        case .optimalToday: "optimal_today"
        case .cycleEndsToday: "cycle_ends_today"
        case .paid: "paid"
        case .onTrack: "on_track"
        }
    }
}

extension TimelineEventKind {
    var iconName: String {
        switch self {
        case .overdue: "exclamationmark.triangle.fill"
        case .paymentDueToday: "bell.badge.fill"
        case .urgent: "clock.badge.exclamationmark.fill"
        case .dueSoon: "calendar.badge.clock"
        case .optimalToday: "sparkles"
        case .cycleEndsToday: "scissors"
        case .paid: "checkmark.seal.fill"
        case .onTrack: "checkmark.circle.fill"
        }
    }

    var titleKey: String {
        switch self {
        case .overdue: "timeline_event_overdue_title"
        case .paymentDueToday: "timeline_event_payment_today_title"
        case .urgent: "timeline_event_urgent_title"
        case .dueSoon: "timeline_event_due_soon_title"
        case .optimalToday: "timeline_event_optimal_title"
        case .cycleEndsToday: "timeline_event_cycle_end_title"
        case .paid: "timeline_event_paid_title"
        case .onTrack: "timeline_event_on_track_title"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .overdue: Color.redStateBackground
        case .paymentDueToday: Color.amberStateBackground
        case .urgent: Color.amberStateBackground
        case .dueSoon: Color.violetStateBackground
        case .optimalToday: Color.violetStateBackground
        case .cycleEndsToday: Color.violetStateBackground.opacity(0.75)
        case .paid: Color.emeraldStateBackground
        case .onTrack: Color(.tertiarySystemFill)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .overdue: Color.redStateForeground
        case .paymentDueToday: Color.amberStateForeground
        case .urgent: Color.amberStateForeground
        case .dueSoon: Color.violetStateForeground
        case .optimalToday: Color.violetStateForeground
        case .cycleEndsToday: Color.violetStateForeground
        case .paid: Color.emeraldStateForeground
        case .onTrack: Color.secondary
        }
    }
}

extension TimelineEvent {
    var subtitle: String {
        switch kind {
        case .overdue:
            return String(format: String(localized: "payments_days_overdue"), status.daysOverdue)
        case .paymentDueToday:
            return String(localized: "timeline_time_today")
        case .urgent, .dueSoon, .onTrack:
            if status.daysUntilPayment == 1 {
                return String(localized: "timeline_time_tomorrow")
            }
            return String(format: String(localized: "payments_days_until"), status.daysUntilPayment)
        case .optimalToday:
            return String(format: String(localized: "payments_days_until"), status.daysUntilPayment)
        case .cycleEndsToday:
            return String(localized: "timeline_time_today")
        case .paid:
            return String(localized: "payments_paid_this_cycle")
        }
    }
}
