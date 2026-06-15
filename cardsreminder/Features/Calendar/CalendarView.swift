import SwiftUI

struct CalendarView: View {
    @Environment(CardsAPIService.self) private var cardsService
    @State private var displayedMonth = Date()
    @State private var selection: CalendarSelection?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let startIndex = calendar.firstWeekday - 1
        let rotated = Array(symbols[startIndex...] + symbols[..<startIndex])
        return rotated.map { String($0.prefix(2)) }
    }

    private var activeCards: [APICard] {
        cardsService.activeCards
    }

    private var year: Int {
        Calendar.current.component(.year, from: displayedMonth)
    }

    private var month: Int {
        Calendar.current.component(.month, from: displayedMonth)
    }

    private var daysInMonth: Int {
        CalendarBillingLogic.daysInMonth(year: year, month: month)
    }

    private var calendarDays: [Int?] {
        CalendarBillingLogic.generateCalendarDays(year: year, month: month)
    }

    private var relevantPeriods: [BillingPeriodInstance] {
        CalendarBillingLogic.periodsRelevantToMonth(cards: activeCards, year: year, month: month)
    }

    private var visibleBillingPeriods: [BillingPeriodInstance] {
        CalendarBillingLogic.billingPeriodsVisibleInMonth(relevantPeriods, year: year, month: month)
    }

    private var visiblePayments: [BillingPeriodInstance] {
        CalendarBillingLogic.paymentsInMonth(relevantPeriods, year: year, month: month)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                screenTitle

                if let errorMessage = cardsService.errorMessage {
                    errorBanner(errorMessage)
                }

                monthHeader

                weekdayLabelsRow

                Divider()

                if activeCards.isEmpty && !cardsService.isLoading {
                    emptyState
                } else {
                    calendarGrid
                        .simultaneousGesture(monthSwipeGesture)
                }

                Divider()

                if !activeCards.isEmpty {
                    CalendarLegendRows(
                        cards: activeCards,
                        billingPeriods: visibleBillingPeriods,
                        payments: visiblePayments,
                        selection: $selection
                    )
                }
            }
        }
        .safeAreaPadding(.bottom)
        .overlay {
            if cardsService.isLoading && activeCards.isEmpty {
                ProgressView()
            }
        }
        .onChange(of: displayedMonth) { _, _ in
            selection = nil
        }
        .task {
            guard !cardsService.hasLoaded else { return }
            await cardsService.fetchCards()
        }
        .refreshable {
            await cardsService.fetchCards()
        }
    }

    private var screenTitle: some View {
        Text("screen_calendar_title")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("calendar_empty_title")
                .font(.subheadline.weight(.medium))
            Text("calendar_empty_message")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                goToPreviousMonth()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }

            Spacer()

            Text(monthYearTitle)
                .font(.headline)

            Spacer()

            Button {
                goToNextMonth()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var weekdayLabelsRow: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 4)
    }

    private var calendarGrid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    DayCell(
                        day: day,
                        isToday: isToday(day: day),
                        bars: barDisplays(for: day)
                    )
                } else {
                    Color.clear
                        .frame(height: 52)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private var monthYearTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var monthSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if value.translation.width < -40 {
                    goToNextMonth()
                } else if value.translation.width > 40 {
                    goToPreviousMonth()
                }
            }
    }

    private func goToPreviousMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }

    private func goToNextMonth() {
        if let newDate = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) {
            displayedMonth = newDate
        }
    }

    private func isToday(day: Int) -> Bool {
        let today = Date()
        let calendar = Calendar.current
        return calendar.component(.year, from: today) == year
            && calendar.component(.month, from: today) == month
            && calendar.component(.day, from: today) == day
    }

    private func barDisplays(for day: Int) -> [DayCell.CardBarDisplay] {
        activeCards.map { card in
            let cardPeriods = relevantPeriods.filter { $0.cardID == card.id }
            let activePeriod = cardPeriods.first {
                CalendarBillingLogic.dayInPeriod($0, year: year, month: month, day: day)
            }
            let paymentPeriod = cardPeriods.first {
                CalendarBillingLogic.isPaymentDay($0, year: year, month: month, day: day)
            }

            let barPeriodId = activePeriod?.id
            let paymentPeriodId = paymentPeriod?.id

            return DayCell.CardBarDisplay(
                id: card.id,
                color: card.color,
                showBar: activePeriod != nil,
                isPeriodStart: activePeriod.map {
                    CalendarBillingLogic.isPeriodSegmentStart($0, year: year, month: month, day: day)
                } ?? false,
                isPeriodEnd: activePeriod.map {
                    CalendarBillingLogic.isPeriodSegmentEnd($0, year: year, month: month, day: day, daysInMonth: daysInMonth)
                } ?? false,
                showPaymentPin: paymentPeriod != nil,
                barHighlighted: isBarHighlighted(periodId: barPeriodId, cardId: card.id),
                pinHighlighted: isPinHighlighted(periodId: paymentPeriodId, cardId: card.id),
                isDimmed: isDimmed(
                    barPeriodId: barPeriodId,
                    paymentPeriodId: paymentPeriodId,
                    cardId: card.id,
                    showBar: activePeriod != nil,
                    showPin: paymentPeriod != nil
                )
            )
        }
    }

    private func isBarHighlighted(periodId: String?, cardId: UUID) -> Bool {
        guard let selection else { return false }

        switch selection {
        case .card(let id):
            return id == cardId
        case .billingPeriod(let id):
            return id == periodId
        case .payment:
            return false
        }
    }

    private func isPinHighlighted(periodId: String?, cardId: UUID) -> Bool {
        guard let selection else { return false }

        switch selection {
        case .card(let id):
            return id == cardId
        case .billingPeriod:
            return false
        case .payment(let id):
            return id == periodId
        }
    }

    private func isDimmed(
        barPeriodId: String?,
        paymentPeriodId: String?,
        cardId: UUID,
        showBar: Bool,
        showPin: Bool
    ) -> Bool {
        guard let selection else { return false }

        switch selection {
        case .card(let id):
            return id != cardId && (showBar || showPin)

        case .billingPeriod(let id):
            if showBar { return barPeriodId != id }
            if showPin { return true }
            return false

        case .payment(let id):
            if showPin { return paymentPeriodId != id }
            if showBar { return true }
            return false
        }
    }
}

#Preview {
    CalendarView()
        .environment(CardsAPIService())
}
