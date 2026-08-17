import SwiftUI
import UIKit

struct CalendarView: View {
    @Environment(CardsAPIService.self) private var cardsService
    @Environment(PaymentsAPIService.self) private var paymentsService
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @AppStorage("calendar.span") private var spanRaw = CalendarSpan.month.rawValue

    @State private var focusedDate = Date()
    @State private var selectedDate: Date?
    @State private var selectedCardID: UUID?
    @State private var periodSlideEdge: Edge = .trailing
    @State private var exportAlert: CalendarExportAlert?
    @State private var sharePayload: ActivitySharePayload?
    @State private var isExporting = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        let monthContents = dayContents

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    errorBanner

                    periodStepper

                    if activeCards.isEmpty && !cardsService.isLoading {
                        emptyState
                    } else {
                        periodContent(monthContents: monthContents)

                        if activeCards.count > 1 {
                            CalendarCardFilterRow(cards: activeCards, selectedCardID: $selectedCardID)
                        }

                        if span != .day {
                            dayDetailPanel(monthContents: monthContents)
                        }
                    }
                }
                .padding(.bottom, 24)
                .animation(motion, value: cardsService.contentRevision)
                .animation(motion, value: paymentsService.dashboardRevision)
                .animation(motion, value: span)
            }
            .background(Color.appBackground)
            .navigationTitle("screen_calendar_title")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar { toolbarContent }
            .overlay {
                if (cardsService.isLoading && activeCards.isEmpty) || isExporting {
                    ProgressView()
                }
            }
            .refreshable { await refreshCalendar() }
            .activityShareSheet(payload: $sharePayload)
            .alert(item: $exportAlert, content: exportAlertView)
        }
        .onAppear { selectDefaultDayIfNeeded() }
        .onChange(of: monthKey) { _, _ in
            if span == .month {
                selectedDate = defaultSelectedDate()
            }
        }
        .onChange(of: span) { _, newSpan in
            if newSpan != .month {
                selectedDate = focusedDate
            }
        }
        .onChange(of: cardsService.contentRevision) { _, _ in
            pruneSelectedCardIfNeeded()
        }
    }

    // MARK: - Derived state

    private var span: CalendarSpan {
        CalendarSpan(rawValue: spanRaw) ?? .month
    }

    private var spanBinding: Binding<CalendarSpan> {
        Binding(
            get: { span },
            set: { newValue in
                Haptics.selection()
                spanRaw = newValue.rawValue
            }
        )
    }

    private var motion: Animation? {
        SmoothRevealAnimation.motion(reduceMotion: reduceMotion)
    }

    private var activeCards: [APICard] {
        cardsService.activeCards
    }

    /// Cards feeding the grid; a chip selection narrows this down to one.
    private var chartedCards: [APICard] {
        guard let selectedCardID else { return activeCards }
        return activeCards.filter { $0.id == selectedCardID }
    }

    private var calendar: Calendar { .current }

    private var year: Int {
        calendar.component(.year, from: focusedDate)
    }

    private var month: Int {
        calendar.component(.month, from: focusedDate)
    }

    private var monthKey: String {
        "\(year)-\(month)"
    }

    private var periodKey: String {
        switch span {
        case .day:
            dayStamp(focusedDate)
        case .week:
            dayStamp(CalendarBillingLogic.startOfWeek(for: focusedDate))
        case .month:
            monthKey
        }
    }

    private func dayStamp(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(parts.year ?? 0)-\(parts.month ?? 0)-\(parts.day ?? 0)"
    }

    private var calendarDays: [Int?] {
        CalendarBillingLogic.generateCalendarDays(year: year, month: month)
    }

    private var weekDates: [Date] {
        CalendarBillingLogic.datesInWeek(containing: focusedDate)
    }

    private var dayContents: [Int: CalendarDayContent] {
        buildMonthContents(year: year, month: month)
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let startIndex = calendar.firstWeekday - 1
        let rotated = Array(symbols[startIndex...] + symbols[..<startIndex])
        return rotated.map { String($0.prefix(2)) }
    }

    private var isViewingCurrentMonth: Bool {
        calendar.isDate(focusedDate, equalTo: Date(), toGranularity: .month)
    }

    private var isViewingCurrentPeriod: Bool {
        switch span {
        case .day:
            calendar.isDateInToday(focusedDate)
        case .week:
            weekDates.contains(where: { calendar.isDateInToday($0) })
        case .month:
            isViewingCurrentMonth
        }
    }

    private var todayDay: Int? {
        guard isViewingCurrentMonth else { return nil }
        return calendar.component(.day, from: Date())
    }

    private var periodTitle: String {
        switch span {
        case .day:
            return focusedDate.formatted(.dateTime.weekday(.wide).day().month(.wide))
        case .week:
            let start = weekDates.first ?? focusedDate
            let end = weekDates.last ?? focusedDate
            return "\(start.formatted(.dateTime.day().month(.abbreviated))) – \(end.formatted(.dateTime.day().month(.abbreviated).year()))"
        case .month:
            return focusedDate.formatted(.dateTime.month(.wide).year())
        }
    }

    // MARK: - Toolbar and period navigation

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            spanMenu
        }

        ToolbarItem(placement: .topBarTrailing) {
            exportMenu
        }

        if !isViewingCurrentPeriod {
            ToolbarItem(placement: .topBarTrailing) {
                Button("calendar_action_today") {
                    goToToday()
                }
                .font(.subheadline.weight(.semibold))
            }
        }
    }

    private var spanMenu: some View {
        Menu {
            Picker(selection: spanBinding) {
                ForEach(CalendarSpan.allCases) { option in
                    Label(option.labelKey, systemImage: option.iconName)
                        .tag(option)
                }
            } label: {
                Text("calendar_span_menu")
            }
        } label: {
            Image(systemName: span.iconName)
        }
        .accessibilityLabel(Text("calendar_span_menu"))
    }

    private var exportMenu: some View {
        Menu {
            Button {
                Task { await addToAppleCalendar() }
            } label: {
                Label("calendar_export_apple", systemImage: "calendar.badge.plus")
            }

            Button {
                Task { await shareICS() }
            } label: {
                Label("calendar_export_ics", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .disabled(activeCards.isEmpty || isExporting)
        .accessibilityLabel(Text("calendar_a11y_export"))
    }

    private var periodStepper: some View {
        HStack(spacing: 0) {
            Button {
                changePeriod(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text(span.previousAccessibilityKey))

            Spacer(minLength: 0)

            Text(periodTitle)
                .font(.headline)
                .multilineTextAlignment(.center)
                .contentTransition(.identity)

            Spacer(minLength: 0)

            Button {
                changePeriod(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel(Text(span.nextAccessibilityKey))
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Period content

    @ViewBuilder
    private func periodContent(monthContents: [Int: CalendarDayContent]) -> some View {
        switch span {
        case .month:
            calendarSection(contents: monthContents)
        case .week:
            CalendarWeekList(
                dates: weekDates,
                contents: contents(for: weekDates),
                selectedDate: selectedDate,
                onSelect: { date in
                    focusedDate = date
                    selectedDate = calendar.isDate(date, inSameDayAs: selectedDate ?? .distantPast) ? nil : date
                }
            )
            .id(periodKey)
            .transition(periodTransition)
            .simultaneousGesture(periodSwipeGesture)
        case .day:
            CalendarDayDetailPanel(
                date: focusedDate,
                isToday: calendar.isDateInToday(focusedDate),
                content: content(for: focusedDate),
                showsHeader: false
            )
            .padding(.horizontal, 16)
            .id(periodKey)
            .transition(periodTransition)
            .simultaneousGesture(periodSwipeGesture)
        }
    }

    // MARK: - Grid

    private func calendarSection(contents: [Int: CalendarDayContent]) -> some View {
        VStack(spacing: 0) {
            weekdayLabelsRow

            ZStack {
                calendarGrid(contents: contents)
                    .id(periodKey)
                    .transition(periodTransition)
            }
            .clipped()
            .simultaneousGesture(periodSwipeGesture)
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.defaultBorder, lineWidth: 1)
        }
        .padding(.horizontal, 16)
    }

    private var periodTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }

        let leaving: Edge = periodSlideEdge == .trailing ? .leading : .trailing
        return .asymmetric(
            insertion: .move(edge: periodSlideEdge).combined(with: .opacity),
            removal: .move(edge: leaving).combined(with: .opacity)
        )
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
        .accessibilityHidden(true)
    }

    private func calendarGrid(contents: [Int: CalendarDayContent]) -> some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(for: day, content: contents[day] ?? CalendarDayContent())
                } else {
                    Color.clear.frame(height: 1)
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }

    private func dayCell(for day: Int, content: CalendarDayContent) -> some View {
        let visibleBars = content.periods.prefix(DayCell.barSlots)
        let visibleDots = content.payments.prefix(DayCell.dotSlots)
        let hiddenMarks = (content.periods.count - visibleBars.count)
            + (content.payments.count - visibleDots.count)
        let cellDate = date(year: year, month: month, day: day)

        return DayCell(
            day: day,
            isToday: todayDay == day,
            isSelected: selectedDate.map { calendar.isDate($0, inSameDayAs: cellDate) } ?? false,
            bars: visibleBars.map { period in
                DayCell.PeriodBar(
                    id: period.id,
                    color: period.color,
                    isSegmentStart: period.isSegmentStart,
                    isSegmentEnd: period.isSegmentEnd,
                    isCutDay: period.isCutDay
                )
            },
            dots: visibleDots.map { payment in
                DayCell.PaymentDot(
                    id: payment.id,
                    color: payment.color,
                    ringColor: payment.state.gridRingColor,
                    isSettled: payment.state.isSettled
                )
            },
            hiddenMarkCount: hiddenMarks,
            accessibilityText: accessibilityText(for: day, content: content)
        )
        .onTapGesture {
            Haptics.selection()
            withAnimation(motion) {
                focusedDate = cellDate
                selectedDate = selectedDate.map { calendar.isDate($0, inSameDayAs: cellDate) } == true
                    ? nil
                    : cellDate
            }
        }
    }

    private func accessibilityText(for day: Int, content: CalendarDayContent) -> String {
        var parts: [String] = []

        parts.append(
            date(year: year, month: month, day: day)
                .formatted(.dateTime.weekday(.wide).day().month(.wide))
        )

        if todayDay == day {
            parts.append(String(localized: "calendar_action_today"))
        }

        if !content.payments.isEmpty {
            parts.append(
                String(format: String(localized: "calendar_a11y_day_payments"), content.payments.count)
            )
        }

        if !content.periods.isEmpty {
            parts.append(
                String(format: String(localized: "calendar_a11y_day_periods"), content.periods.count)
            )
        }

        return parts.joined(separator: ". ")
    }

    // MARK: - Panels

    @ViewBuilder
    private func dayDetailPanel(monthContents: [Int: CalendarDayContent]) -> some View {
        if let selectedDate {
            CalendarDayDetailPanel(
                date: selectedDate,
                isToday: calendar.isDateInToday(selectedDate),
                content: content(for: selectedDate, monthContents: monthContents)
            )
            .padding(.horizontal, 16)
            .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
            Text("calendar_hint_select_day")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let message = cardsService.errorMessage ?? paymentsService.errorMessage {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.amberStateForeground)

                Text(message)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("action_retry") {
                    Task { await refreshCalendar() }
                }
                .font(.caption.weight(.semibold))
            }
            .padding(12)
            .background(
                Color.amberStateBackground.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .padding(.horizontal, 16)
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar")
                .font(.system(size: 40))
                .foregroundStyle(Color.primaryAction)

            VStack(spacing: 8) {
                Text("calendar_empty_title")
                    .font(.title3.weight(.semibold))

                Text("calendar_empty_message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                Haptics.lightImpact()
                navigation.openCreateCard()
            } label: {
                Label("action_add_card", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .foregroundStyle(.white)
                    .background(Color.primaryAction)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.horizontal, 20)
    }

    // MARK: - Actions

    private var periodSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if value.translation.width < -40 {
                    changePeriod(by: 1)
                } else if value.translation.width > 40 {
                    changePeriod(by: -1)
                }
            }
    }

    private func changePeriod(by value: Int) {
        guard let newDate = calendar.date(byAdding: span.stepComponent, value: value, to: focusedDate) else {
            return
        }

        Haptics.selection()
        periodSlideEdge = value > 0 ? .trailing : .leading
        withAnimation(motion) {
            focusedDate = newDate
            if span != .month {
                selectedDate = newDate
            }
        }
    }

    private func goToToday() {
        let today = Date()
        Haptics.lightImpact()
        periodSlideEdge = today > focusedDate ? .trailing : .leading
        withAnimation(motion) {
            focusedDate = today
            selectedDate = today
        }
    }

    private func selectDefaultDayIfNeeded() {
        guard selectedDate == nil else { return }
        selectedDate = defaultSelectedDate()
    }

    /// Keeps the panel useful right away: today when it is on screen, otherwise the
    /// first day of the month that actually has a payment.
    private func defaultSelectedDate() -> Date? {
        if let todayDay {
            return date(year: year, month: month, day: todayDay)
        }

        if let firstPaymentDay = dayContents.filter({ !$0.value.payments.isEmpty }).keys.min() {
            return date(year: year, month: month, day: firstPaymentDay)
        }

        return nil
    }

    private func pruneSelectedCardIfNeeded() {
        guard let selectedCardID, !activeCards.contains(where: { $0.id == selectedCardID }) else { return }
        self.selectedCardID = nil
    }

    private func refreshCalendar() async {
        async let cards: Void = cardsService.fetchCards(silentUnlessEmpty: false)
        async let dashboard: Void = paymentsService.fetchDashboard(silentUnlessEmpty: false)
        _ = await (cards, dashboard)
    }

    // MARK: - Export

    private func exportEvents() -> [CalendarExportEvent] {
        CalendarExportBuilder.events(cards: chartedCards, year: year, month: month)
    }

    private func addToAppleCalendar() async {
        let events = exportEvents()
        guard !events.isEmpty else {
            exportAlert = .empty
            return
        }

        isExporting = true
        defer { isExporting = false }

        do {
            let count = try await CalendarAppleExporter.add(events: events)
            Haptics.success()
            exportAlert = .success(count)
        } catch CalendarExportError.accessDenied {
            exportAlert = .denied
        } catch {
            exportAlert = .failed
        }
    }

    private func shareICS() async {
        let events = exportEvents()
        guard !events.isEmpty else {
            exportAlert = .empty
            return
        }

        isExporting = true
        defer { isExporting = false }

        do {
            let url = try CalendarExportBuilder.writeTemporaryICS(events: events, year: year, month: month)
            sharePayload = ActivitySharePayload(items: [url])
        } catch {
            exportAlert = .failed
        }
    }

    private func exportAlertView(_ alert: CalendarExportAlert) -> Alert {
        switch alert {
        case .success(let count):
            Alert(
                title: Text("calendar_export_success_title"),
                message: Text(String(format: String(localized: "calendar_export_success_message"), count))
            )
        case .empty:
            Alert(
                title: Text("calendar_export_empty_title"),
                message: Text("calendar_export_empty_message")
            )
        case .denied:
            Alert(
                title: Text("calendar_export_denied_title"),
                message: Text("calendar_export_denied_message"),
                primaryButton: .default(Text("calendar_export_open_settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                },
                secondaryButton: .cancel(Text("action_cancel"))
            )
        case .failed:
            Alert(
                title: Text("calendar_export_failed_title"),
                message: Text("calendar_export_failed_message")
            )
        }
    }

    // MARK: - Date helpers

    private func buildMonthContents(year: Int, month: Int) -> [Int: CalendarDayContent] {
        let periods = CalendarBillingLogic.periodsRelevantToMonth(
            cards: chartedCards,
            year: year,
            month: month
        )

        return CalendarMonthBuilder.build(
            cards: chartedCards,
            periods: periods,
            year: year,
            month: month,
            status: { paymentsService.status(for: $0) }
        )
    }

    private func contents(for dates: [Date]) -> [Date: CalendarDayContent] {
        var months: [String: [Int: CalendarDayContent]] = [:]
        var result: [Date: CalendarDayContent] = [:]

        for date in dates {
            let year = calendar.component(.year, from: date)
            let month = calendar.component(.month, from: date)
            let key = "\(year)-\(month)"
            if months[key] == nil {
                months[key] = buildMonthContents(year: year, month: month)
            }
            let day = calendar.component(.day, from: date)
            result[calendar.startOfDay(for: date)] = months[key]?[day] ?? CalendarDayContent()
        }

        return result
    }

    private func content(
        for date: Date,
        monthContents: [Int: CalendarDayContent]? = nil
    ) -> CalendarDayContent {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        let day = calendar.component(.day, from: date)

        if year == self.year, month == self.month, let monthContents {
            return monthContents[day] ?? CalendarDayContent()
        }

        return buildMonthContents(year: year, month: month)[day] ?? CalendarDayContent()
    }

    private func date(year: Int, month: Int, day: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? focusedDate
    }
}

private enum CalendarExportAlert: Identifiable {
    case success(Int)
    case empty
    case denied
    case failed

    var id: String {
        switch self {
        case .success(let count): "success-\(count)"
        case .empty: "empty"
        case .denied: "denied"
        case .failed: "failed"
        }
    }
}

#Preview {
    CalendarView()
        .environment(CardsAPIService())
        .environment(PaymentsAPIService())
        .environment(AppNavigation())
}
