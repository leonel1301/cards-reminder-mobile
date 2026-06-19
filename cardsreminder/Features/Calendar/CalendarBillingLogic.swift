import Foundation

struct BillingPeriodInstance: Identifiable, Hashable {
    let id: String
    let cardName: String
    let cardColorHex: String
    let cardID: UUID

    let startYear: Int
    let startMonth: Int
    let startDay: Int

    let endYear: Int
    let endMonth: Int
    let endDay: Int

    let paymentYear: Int
    let paymentMonth: Int
    let paymentDay: Int

    var periodLabel: String {
        CalendarBillingLogic.formatPeriodRange(
            startYear: startYear, startMonth: startMonth, startDay: startDay,
            endYear: endYear, endMonth: endMonth, endDay: endDay
        )
    }

    var paymentDateLabel: String {
        CalendarBillingLogic.formatDayMonth(
            year: paymentYear, month: paymentMonth, day: paymentDay
        )
    }

    var paymentSummaryLabel: String {
        String(
            format: String(localized: "payment_summary"),
            paymentDateLabel
        )
    }

    var paymentDetailLabel: String {
        String(
            format: String(localized: "payment_detail_format"),
            paymentSummaryLabel,
            periodLabel
        )
    }
}

enum CalendarSelection: Hashable {
    case card(UUID)
    case billingPeriod(String)
    case payment(String)
}

enum CalendarBillingLogic {
    private static var currentLocale: Locale { .current }

    static func daysInMonth(year: Int, month: Int) -> Int {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        let calendar = Calendar.current
        guard let date = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: date) else {
            return 30
        }
        return range.count
    }

    static func generateCalendarDays(year: Int, month: Int) -> [Int?] {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        let calendar = Calendar.current
        guard let firstOfMonth = calendar.date(from: components),
              let dayRange = calendar.range(of: .day, in: .month, for: firstOfMonth) else {
            return []
        }

        let leadingBlanks = calendar.component(.weekday, from: firstOfMonth) - 1
        var days = Array<Int?>(repeating: nil, count: leadingBlanks)
        days.append(contentsOf: dayRange.map { $0 })
        return days
    }

    static func addMonths(year: Int, month: Int, delta: Int) -> (year: Int, month: Int) {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1

        guard let date = Calendar.current.date(from: components),
              let shifted = Calendar.current.date(byAdding: .month, value: delta, to: date) else {
            return (year, month)
        }

        return (
            Calendar.current.component(.year, from: shifted),
            Calendar.current.component(.month, from: shifted)
        )
    }

    static func makePeriod(card: APICard, startYear: Int, startMonth: Int) -> BillingPeriodInstance {
        let (endYear, endMonth) = addMonths(year: startYear, month: startMonth, delta: 1)
        let (paymentYear, paymentMonth) = addMonths(year: endYear, month: endMonth, delta: 1)

        return BillingPeriodInstance(
            id: "\(card.id.uuidString)-\(startYear)-\(startMonth)",
            cardName: card.name,
            cardColorHex: card.displayColorHex,
            cardID: card.id,
            startYear: startYear,
            startMonth: startMonth,
            startDay: card.periodStartDay,
            endYear: endYear,
            endMonth: endMonth,
            endDay: card.periodEndDay,
            paymentYear: paymentYear,
            paymentMonth: paymentMonth,
            paymentDay: card.paymentDay
        )
    }

    static func periodsRelevantToMonth(cards: [APICard], year: Int, month: Int) -> [BillingPeriodInstance] {
        var result: [BillingPeriodInstance] = []
        var seen = Set<String>()

        for card in cards {
            for delta in -2...1 {
                let (startYear, startMonth) = addMonths(year: year, month: month, delta: delta)
                let period = makePeriod(card: card, startYear: startYear, startMonth: startMonth)
                guard !seen.contains(period.id) else { continue }

                if period.overlapsBillingMonth(year: year, month: month)
                    || period.hasPaymentInMonth(year: year, month: month) {
                    seen.insert(period.id)
                    result.append(period)
                }
            }
        }

        return result.sorted { lhs, rhs in
            if lhs.startYear != rhs.startYear { return lhs.startYear < rhs.startYear }
            if lhs.startMonth != rhs.startMonth { return lhs.startMonth < rhs.startMonth }
            return lhs.cardName.localizedCompare(rhs.cardName) == .orderedAscending
        }
    }

    static func billingPeriodsVisibleInMonth(_ periods: [BillingPeriodInstance], year: Int, month: Int) -> [BillingPeriodInstance] {
        periods.filter { $0.overlapsBillingMonth(year: year, month: month) }
    }

    static func paymentsInMonth(_ periods: [BillingPeriodInstance], year: Int, month: Int) -> [BillingPeriodInstance] {
        periods.filter { $0.hasPaymentInMonth(year: year, month: month) }
    }

    static func dayInPeriod(_ period: BillingPeriodInstance, year: Int, month: Int, day: Int) -> Bool {
        guard (1...31).contains(day) else { return false }

        if year == period.startYear, month == period.startMonth, day >= period.startDay {
            return true
        }

        if year == period.endYear, month == period.endMonth, day <= period.endDay {
            return true
        }

        return false
    }

    static func isPaymentDay(_ period: BillingPeriodInstance, year: Int, month: Int, day: Int) -> Bool {
        period.paymentYear == year && period.paymentMonth == month && period.paymentDay == day
    }

    static func isPeriodSegmentStart(_ period: BillingPeriodInstance, year: Int, month: Int, day: Int) -> Bool {
        guard dayInPeriod(period, year: year, month: month, day: day) else { return false }

        if year == period.startYear, month == period.startMonth, day == period.startDay {
            return true
        }

        if year == period.endYear, month == period.endMonth, day == 1,
           year != period.startYear || month != period.startMonth {
            return true
        }

        return false
    }

    static func isPeriodSegmentEnd(
        _ period: BillingPeriodInstance,
        year: Int,
        month: Int,
        day: Int,
        daysInMonth: Int
    ) -> Bool {
        guard dayInPeriod(period, year: year, month: month, day: day) else { return false }

        if year == period.endYear, month == period.endMonth, day == period.endDay {
            return true
        }

        if year == period.startYear, month == period.startMonth, day == daysInMonth,
           year != period.endYear || month != period.endMonth {
            return true
        }

        return false
    }

    static func formatPeriodRange(
        startYear: Int, startMonth: Int, startDay: Int,
        endYear: Int, endMonth: Int, endDay: Int
    ) -> String {
        let start = formatDayMonth(year: startYear, month: startMonth, day: startDay)
        let end = formatDayMonth(year: endYear, month: endMonth, day: endDay)
        return "\(start) – \(end)"
    }

    static func formatDayMonth(year: Int, month: Int, day: Int) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        guard let date = Calendar.current.date(from: components) else {
            return "\(day)/\(month)"
        }

        return date.formatted(.dateTime.day().month(.abbreviated).locale(currentLocale))
    }

    static func currentPeriod(for card: APICard, referenceDate: Date = .now) -> BillingPeriodInstance {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: referenceDate)
        let month = calendar.component(.month, from: referenceDate)
        let day = calendar.component(.day, from: referenceDate)

        for delta in -1...0 {
            let (startYear, startMonth) = addMonths(year: year, month: month, delta: delta)
            let period = makePeriod(card: card, startYear: startYear, startMonth: startMonth)
            if dayInPeriod(period, year: year, month: month, day: day) {
                return period
            }
        }

        return makePeriod(card: card, startYear: year, startMonth: month)
    }

    static func cycleEndDate(for period: BillingPeriodInstance) -> Date? {
        dateComponents(year: period.endYear, month: period.endMonth, day: period.endDay)
    }

    static func cycleStartDate(for period: BillingPeriodInstance) -> Date? {
        dateComponents(year: period.startYear, month: period.startMonth, day: period.startDay)
    }

    static func paymentDueDate(for period: BillingPeriodInstance) -> Date? {
        dateComponents(year: period.paymentYear, month: period.paymentMonth, day: period.paymentDay)
    }

    private static func dateComponents(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return Calendar.current.date(from: components)
    }
}

extension BillingPeriodInstance {
    func overlapsBillingMonth(year: Int, month: Int) -> Bool {
        if startYear == year, startMonth == month { return true }
        if endYear == year, endMonth == month { return true }
        return false
    }

    func hasPaymentInMonth(year: Int, month: Int) -> Bool {
        paymentYear == year && paymentMonth == month
    }
}
