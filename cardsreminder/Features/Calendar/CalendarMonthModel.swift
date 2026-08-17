import Foundation
import SwiftUI

enum CalendarPaymentState: Hashable {
    /// The cycle this payment belongs to is already settled.
    case paid
    /// Due date has passed and the API still reports it as unpaid.
    case overdue
    /// Belongs to the cycle the API is currently tracking, still pending.
    case due
    /// Later than the cycle the API tracks, so there is nothing to settle yet.
    case upcoming
    /// Older than the tracked cycle: the dashboard no longer carries its outcome.
    case past

    var labelKey: LocalizedStringKey {
        switch self {
        case .paid: "calendar_payment_state_paid"
        case .overdue: "calendar_payment_state_overdue"
        case .due: "calendar_payment_state_due"
        case .upcoming, .past: "calendar_payment_state_scheduled"
        }
    }

    var accentColor: Color {
        switch self {
        case .paid: Color.emeraldStateForeground
        case .overdue: Color.redStateForeground
        case .due: Color.amberStateForeground
        case .upcoming, .past: Color.secondary
        }
    }

    var badgeBackground: Color {
        switch self {
        case .paid: Color.emeraldStateBackground
        case .overdue: Color.redStateBackground
        case .due: Color.amberStateBackground
        case .upcoming, .past: Color(.tertiarySystemFill)
        }
    }

    /// Ring drawn around the grid dot. Nothing to flag for payments the dashboard
    /// is not tracking, so they stay a plain card-coloured dot.
    var gridRingColor: Color? {
        switch self {
        case .paid: Color.emeraldStateForeground
        case .overdue: Color.redStateForeground
        case .due: Color.amberStateForeground
        case .upcoming, .past: nil
        }
    }

    var isSettled: Bool {
        self == .paid
    }
}

struct CalendarPeriodMark: Identifiable, Hashable {
    let id: String
    let cardID: UUID
    let cardName: String
    let colorHex: String
    let periodLabel: String
    let isSegmentStart: Bool
    let isSegmentEnd: Bool
    let isCutDay: Bool

    var color: Color { Color(hex: colorHex) }
}

struct CalendarPaymentMark: Identifiable, Hashable {
    let id: String
    let cardID: UUID
    let cardName: String
    let colorHex: String
    let periodLabel: String
    let state: CalendarPaymentState

    var color: Color { Color(hex: colorHex) }
}

struct CalendarDayContent: Hashable {
    var periods: [CalendarPeriodMark] = []
    var payments: [CalendarPaymentMark] = []
    var optimalPurchaseCardNames: [String] = []

    var isEmpty: Bool {
        periods.isEmpty && payments.isEmpty && optimalPurchaseCardNames.isEmpty
    }
}

enum CalendarMonthBuilder {
    /// Precomputes everything the grid and the day panel need, so cells stop
    /// re-scanning every period on each render.
    static func build(
        cards: [APICard],
        periods: [BillingPeriodInstance],
        year: Int,
        month: Int,
        status: (UUID) -> APICardStatus?,
        referenceDate: Date = .now
    ) -> [Int: CalendarDayContent] {
        let daysInMonth = CalendarBillingLogic.daysInMonth(year: year, month: month)
        guard daysInMonth > 0 else { return [:] }

        var contents: [Int: CalendarDayContent] = [:]

        for period in periods {
            let resolvedPaymentState = paymentState(
                for: period,
                status: status(period.cardID),
                referenceDate: referenceDate
            )

            for day in 1...daysInMonth {
                if CalendarBillingLogic.dayInPeriod(period, year: year, month: month, day: day) {
                    contents[day, default: CalendarDayContent()].periods.append(
                        CalendarPeriodMark(
                            id: period.id,
                            cardID: period.cardID,
                            cardName: period.cardName,
                            colorHex: period.cardColorHex,
                            periodLabel: period.periodLabel,
                            isSegmentStart: CalendarBillingLogic.isPeriodSegmentStart(
                                period, year: year, month: month, day: day
                            ),
                            isSegmentEnd: CalendarBillingLogic.isPeriodSegmentEnd(
                                period, year: year, month: month, day: day, daysInMonth: daysInMonth
                            ),
                            isCutDay: period.endYear == year
                                && period.endMonth == month
                                && period.endDay == day
                        )
                    )
                }

                if CalendarBillingLogic.isPaymentDay(period, year: year, month: month, day: day) {
                    contents[day, default: CalendarDayContent()].payments.append(
                        CalendarPaymentMark(
                            id: period.id,
                            cardID: period.cardID,
                            cardName: period.cardName,
                            colorHex: period.cardColorHex,
                            periodLabel: period.periodLabel,
                            state: resolvedPaymentState
                        )
                    )
                }
            }
        }

        addOptimalPurchaseDays(
            to: &contents,
            cards: cards,
            year: year,
            month: month,
            status: status,
            referenceDate: referenceDate
        )

        for day in Array(contents.keys) {
            contents[day]?.periods.sort { $0.cardName.localizedCompare($1.cardName) == .orderedAscending }
            contents[day]?.payments.sort { $0.cardName.localizedCompare($1.cardName) == .orderedAscending }
        }

        return contents
    }

    static func paymentState(
        for period: BillingPeriodInstance,
        status: APICardStatus?,
        referenceDate: Date
    ) -> CalendarPaymentState {
        let calendar = Calendar.current

        guard let dueDate = CalendarBillingLogic.paymentDueDate(for: period) else {
            return .upcoming
        }

        // The dashboard only reports one cycle per card, so anything outside it
        // can only be described as scheduled or already elapsed.
        if let status, calendar.isDate(status.paymentDueDate, inSameDayAs: dueDate) {
            if status.isPaidThisCycle { return .paid }
            if status.daysOverdue > 0 { return .overdue }
            return .due
        }

        return dueDate < calendar.startOfDay(for: referenceDate) ? .past : .upcoming
    }

    /// The API reports the optimal purchase day as a day number for the cycle it is
    /// currently tracking, so it can only be placed on the month that contains today.
    private static func addOptimalPurchaseDays(
        to contents: inout [Int: CalendarDayContent],
        cards: [APICard],
        year: Int,
        month: Int,
        status: (UUID) -> APICardStatus?,
        referenceDate: Date
    ) {
        let calendar = Calendar.current
        guard calendar.component(.year, from: referenceDate) == year,
              calendar.component(.month, from: referenceDate) == month else {
            return
        }

        for card in cards {
            guard let cardStatus = status(card.id) else { continue }
            let day = cardStatus.optimalPurchaseDay
            guard (1...31).contains(day) else { continue }

            contents[day, default: CalendarDayContent()].optimalPurchaseCardNames.append(card.name)
        }

        for day in Array(contents.keys) {
            contents[day]?.optimalPurchaseCardNames.sort {
                $0.localizedCompare($1) == .orderedAscending
            }
        }
    }
}
