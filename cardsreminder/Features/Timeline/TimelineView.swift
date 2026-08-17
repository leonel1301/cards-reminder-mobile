import SwiftUI

struct TimelineView: View {
    @Environment(CardsAPIService.self) private var cardsService
    @Environment(PaymentsAPIService.self) private var paymentsService
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var paymentsCard: APICard?
    @State private var cardPendingPayment: APICard?
    @State private var markingPaidCardID: UUID?
    @State private var openSwipeEventID: String?
    @State private var isAllClearExpanded = false
    @State private var isContentRevealed = false
    @State private var isFeelingExplanationPresented = false

    var body: some View {
        // Built once per pass instead of on every access of `buildResult`.
        let result = buildResult

        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    errorBanner

                    if paymentsService.dashboardCards.isEmpty && !isInitialLoading {
                        emptyState
                            .transition(SmoothRevealAnimation.sectionTransition)
                    } else {
                        loadedContent(result)
                            .transition(SmoothRevealAnimation.sectionTransition)
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
                .animation(motion, value: paymentsService.dashboardRevision)
            }
            .background(Color.appBackground)
            .navigationTitle("screen_timeline_title")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.automatic, for: .navigationBar)
            .refreshable {
                guard !isFeelingExplanationPresented else { return }
                await refreshTimeline()
            }
        }
        .overlay {
            if isInitialLoading {
                ProgressView()
            }
        }
        .onAppear { revealContentIfNeeded() }
        .onChange(of: paymentsService.dashboardRevision) { _, _ in
            openSwipeEventID = nil
            revealContentIfNeeded()
        }
        .sheet(item: $paymentsCard) { card in
            CardPaymentsSheet(card: card)
        }
        .alert(
            "payments_quick_confirm_title",
            isPresented: showPaymentConfirmation,
            presenting: cardPendingPayment
        ) { card in
            Button("action_cancel", role: .cancel) {
                cardPendingPayment = nil
            }
            Button("payments_mark_paid") {
                cardPendingPayment = nil
                Task { await quickMarkPaid(card) }
            }
        } message: { card in
            Text(PaymentConfirmationCopy.message(for: paymentsService.status(for: card.id)))
        }
    }

    // MARK: - Derived state

    private var motion: Animation? {
        SmoothRevealAnimation.motion(reduceMotion: reduceMotion)
    }

    private var buildResult: TimelineBuildResult {
        TimelineEventBuilder.build(
            from: paymentsService.dashboardCards,
            excludingCardID: paymentsService.bestForPurchase?.cardID
        )
    }

    private var featuredEntry: DashboardCardEntry? {
        guard let bestForPurchase = paymentsService.bestForPurchase else { return nil }
        return paymentsService.dashboardCards.first { $0.card.id == bestForPurchase.cardID }
    }

    private var isInitialLoading: Bool {
        paymentsService.isLoadingDashboard && paymentsService.dashboardCards.isEmpty
    }

    private func revealDelay(for index: Int) -> Double {
        reduceMotion ? 0 : SmoothRevealAnimation.staggerDelay(for: index)
    }

    // MARK: - Content

    @ViewBuilder
    private func loadedContent(_ result: TimelineBuildResult) -> some View {
        let actionableSections = result.sections.filter { $0.kind != .allClear }
        let allClearEvents = result.sections.first { $0.kind == .allClear }?.events ?? []

        todayHeaderRow

        if let summary = paymentsService.summary {
            TimelineSummaryStrip(
                summary: summary,
                revealDelay: revealDelay(for: 0),
                isRevealed: isContentRevealed
            )
        }

        if let featuredEntry {
            featuredBlock(featuredEntry)
        }

        if actionableSections.isEmpty && featuredEntry == nil {
            allGoodState
                .padding(.horizontal, 16)
                .opacity(isContentRevealed ? 1 : 0)
                .animation(motion?.delay(revealDelay(for: 1)), value: isContentRevealed)
        }

        if !actionableSections.isEmpty {
            sectionsList(actionableSections)
        }

        if !allClearEvents.isEmpty {
            TimelineAllClearSection(
                events: allClearEvents,
                isExpanded: $isAllClearExpanded,
                onOpenHistory: { paymentsCard = $0.card }
            )
            .padding(.horizontal, 16)
        }
    }

    private var todayHeaderRow: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let summary = paymentsService.summary, !isInitialLoading {
                FinanceFeelingButton(
                    feeling: DashboardFeeling(summary: summary),
                    isExplanationPresented: $isFeelingExplanationPresented
                )
            }
        }
        .padding(.horizontal, 16)
    }

    private func featuredBlock(_ entry: DashboardCardEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelineFeaturedCard(
                card: entry.card,
                status: entry.status,
                revealDelay: revealDelay(for: 1),
                isRevealed: isContentRevealed
            )
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onTapGesture {
                Haptics.lightImpact()
                paymentsCard = entry.card
            }

            if let why = paymentsService.bestForPurchase?.why {
                TimelinePurchaseInsightRow(
                    why: why,
                    revealDelay: revealDelay(for: 2),
                    isRevealed: isContentRevealed
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 4)
    }

    private func sectionsList(_ sections: [TimelineSection]) -> some View {
        let indexedSections = Self.indexedSections(from: sections)

        return VStack(alignment: .leading, spacing: 24) {
            ForEach(Array(indexedSections.enumerated()), id: \.element.section.id) { sectionIndex, item in
                sectionView(item.section, startIndex: item.startIndex, sectionIndex: sectionIndex)
            }
        }
    }

    private func sectionView(
        _ section: TimelineSection,
        startIndex: Int,
        sectionIndex: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(section, sectionIndex: sectionIndex)

            VStack(spacing: 14) {
                ForEach(Array(section.events.enumerated()), id: \.element.id) { eventIndex, event in
                    eventRow(event, revealIndex: startIndex + eventIndex + 3)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func sectionHeader(_ section: TimelineSection, sectionIndex: Int) -> some View {
        HStack(spacing: 8) {
            Text(LocalizedStringKey(section.titleKey))
                .font(.headline)

            Text(verbatim: "\(section.events.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color(.tertiarySystemFill), in: Capsule())
        }
        .padding(.horizontal, 16)
        .opacity(isContentRevealed ? 1 : 0)
        .offset(y: isContentRevealed ? 0 : 6)
        .animation(motion?.delay(revealDelay(for: sectionIndex + 2)), value: isContentRevealed)
        .accessibilityElement(children: .combine)
    }

    private func eventRow(_ event: TimelineEvent, revealIndex: Int) -> some View {
        let markPaidAction: (() -> Void)?
        if event.canMarkPaid {
            markPaidAction = { requestPayment(for: event.card) }
        } else {
            markPaidAction = nil
        }

        return TimelineEventRow(
            event: event,
            revealDelay: revealDelay(for: revealIndex),
            isRevealed: isContentRevealed,
            isMarkingPaid: markingPaidCardID == event.card.id,
            openSwipeID: $openSwipeEventID,
            onOpenHistory: {
                Haptics.lightImpact()
                paymentsCard = event.card
            },
            onMarkPaid: markPaidAction
        )
        .contextMenu {
            if event.canMarkPaid {
                Button {
                    requestPayment(for: event.card)
                } label: {
                    Label("payments_mark_paid", systemImage: "checkmark.circle")
                }
            }

            Button {
                paymentsCard = event.card
            } label: {
                Label("payments_view_history", systemImage: "clock.arrow.circlepath")
            }
        }
    }

    // MARK: - States

    @ViewBuilder
    private var errorBanner: some View {
        if let message = paymentsService.errorMessage, !paymentsService.hasCachedDashboard {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.amberStateForeground)

                Text(message)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("action_retry") {
                    Task { await refreshTimeline() }
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
            Image(systemName: "leaf.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.emeraldStateForeground)

            VStack(spacing: 8) {
                Text("timeline_empty_title")
                    .font(.title3.weight(.semibold))

                Text("timeline_empty_message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button {
                    Haptics.lightImpact()
                    navigation.openCreateCard()
                } label: {
                    Label("timeline_empty_add_card", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(.white)
                        .background(Color.primaryAction)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    Haptics.lightImpact()
                    navigation.openLearn()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("timeline_empty_learn", systemImage: "book.fill")
                            .font(.headline)

                        Text("timeline_empty_learn_subtitle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 28)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.defaultBorder, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 32)
        .padding(.horizontal, 20)
    }

    private var allGoodState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.emeraldStateForeground)

            Text("timeline_all_good_title")
                .font(.subheadline.weight(.medium))

            Text("timeline_all_good_message")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(Color.emeraldStateBackground.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private var showPaymentConfirmation: Binding<Bool> {
        Binding(
            get: { cardPendingPayment != nil },
            set: { if !$0 { cardPendingPayment = nil } }
        )
    }

    private static func indexedSections(
        from sections: [TimelineSection]
    ) -> [(section: TimelineSection, startIndex: Int)] {
        var startIndex = 0
        return sections.map { section in
            let item = (section: section, startIndex: startIndex)
            startIndex += section.events.count
            return item
        }
    }

    private func requestPayment(for card: APICard) {
        Haptics.lightImpact()
        cardPendingPayment = card
    }

    private func refreshTimeline() async {
        async let cards: Void = cardsService.fetchCards(silentUnlessEmpty: false)
        async let dashboard: Void = paymentsService.fetchDashboard(silentUnlessEmpty: false)
        _ = await (cards, dashboard)
    }

    /// Plays the entrance stagger the first time content lands. Replaying it on
    /// every dashboard refresh made the whole screen flash after paying a card.
    private func revealContentIfNeeded() {
        guard !paymentsService.dashboardCards.isEmpty else {
            isContentRevealed = false
            return
        }

        guard !isContentRevealed else { return }

        guard !reduceMotion else {
            isContentRevealed = true
            return
        }

        // The rows must exist in their hidden state for one turn, otherwise
        // SwiftUI renders them already revealed and nothing animates.
        Task { @MainActor in
            withAnimation(SmoothRevealAnimation.motion) {
                isContentRevealed = true
            }
        }
    }

    private func quickMarkPaid(_ card: APICard) async {
        markingPaidCardID = card.id
        defer { markingPaidCardID = nil }

        guard let response = await paymentsService.markAsPaid(cardID: card.id) else { return }

        if let index = cardsService.cards.firstIndex(where: { $0.id == response.card.id }) {
            cardsService.cards[index] = response.card
        }

        Haptics.success()
    }
}

#Preview {
    TimelineView()
        .environment(CardsAPIService())
        .environment(PaymentsAPIService())
        .environment(AppNavigation())
}
