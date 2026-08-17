import SwiftUI

struct CardsView: View {
    /// How long the user gets to undo a deletion before it reaches the API.
    private static let undoWindow: Duration = .seconds(4.5)

    @Environment(CardsAPIService.self) private var cardsService
    @Environment(PaymentsAPIService.self) private var paymentsService
    @Environment(OwnersAPIService.self) private var ownersService
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var query = CardsListQuery()
    @State private var openCardID: UUID?
    @State private var openInactiveCardID: UUID?
    @State private var showsInactiveSection = false
    @State private var editingCard: APICard?
    @State private var paymentsCard: APICard?
    @State private var cardPendingPayment: APICard?
    @State private var markingPaidCardID: UUID?
    @State private var pendingDeletion: PendingCardDeletion?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    CardsSummaryStrip(
                        counts: statusCounts,
                        totalCount: cardsService.cards.count,
                        selection: $query.statusFilter
                    )

                    errorBanner

                    content
                }
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .background(Color.appBackground)
            .navigationTitle("screen_cards_title")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.automatic, for: .navigationBar)
            .toolbar { toolbarContent }
            .searchable(
                text: $query.searchText,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: Text("cards_search_prompt")
            )
            .refreshable { await refreshCardsScreen() }
            .safeAreaInset(edge: .bottom) { undoBar }
        }
        .task { await loadOwnersIfNeeded() }
        .sheet(item: $editingCard, onDismiss: {
            Task { await refreshCardsScreen() }
        }) { card in
            CardFormView(mode: .edit(card))
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
            Text(quickPaymentConfirmationMessage(for: card))
        }
    }

    // MARK: - Derived state

    private var motion: Animation? {
        SmoothRevealAnimation.motion(reduceMotion: reduceMotion)
    }

    /// Cards awaiting an undoable deletion are already gone from the user's point of view.
    private var listedCards: [APICard] {
        guard let pendingDeletion else { return cardsService.cards }
        return cardsService.cards.filter { $0.id != pendingDeletion.card.id }
    }

    private var arrangedCards: [APICard] {
        CardsListArrangement.apply(query, to: listedCards) { paymentsService.status(for: $0) }
    }

    private var visibleActiveCards: [APICard] {
        arrangedCards.filter(\.isActive)
    }

    private var visibleInactiveCards: [APICard] {
        arrangedCards.filter { !$0.isActive }
    }

    private var statusCounts: [CardPaymentStatusKind: Int] {
        CardsListArrangement.statusCounts(for: listedCards) { paymentsService.status(for: $0) }
    }

    private var errorMessage: String? {
        cardsService.errorMessage ?? paymentsService.errorMessage
    }

    private var selectableOwners: [APIOwner] {
        let usedOwnerIDs = Set(cardsService.cards.map(\.ownerID))
        return ownersService.owners.filter { usedOwnerIDs.contains($0.id) }
    }

    private func entries(for cards: [APICard]) -> [CardWalletEntry] {
        cards.map { CardWalletEntry(card: $0, status: paymentsService.status(for: $0.id)) }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            refinementMenu
        }

        ToolbarItem(placement: .topBarTrailing) {
            Button {
                Haptics.lightImpact()
                navigation.openCreateCard()
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(Text("action_add_card"))
        }
    }

    private var refinementMenu: some View {
        Menu {
            Picker(selection: $query.sortOrder) {
                ForEach(CardsSortOrder.allCases) { order in
                    Text(order.labelKey).tag(order)
                }
            } label: {
                Text("cards_sort_label")
            }

            if selectableOwners.count > 1 {
                Picker(selection: $query.ownerID) {
                    Text("cards_filter_all_owners").tag(UUID?.none)
                    ForEach(selectableOwners) { owner in
                        Text(owner.displayName).tag(UUID?.some(owner.id))
                    }
                } label: {
                    Text("field_card_owner")
                }
            }

            if query.isRefined {
                Divider()

                Button(role: .destructive) {
                    withAnimation(motion) { query.clearRefinements() }
                } label: {
                    Label("cards_clear_filters", systemImage: "xmark.circle")
                }
            }
        } label: {
            Image(
                systemName: query.isRefined
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle"
            )
        }
        .accessibilityLabel(Text("cards_sort_label"))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if cardsService.cards.isEmpty {
            if cardsService.isLoading {
                loadingPlaceholder
            } else {
                emptyState
            }
        } else if visibleActiveCards.isEmpty && visibleInactiveCards.isEmpty {
            noResultsState
        } else {
            VStack(alignment: .leading, spacing: 24) {
                if !visibleActiveCards.isEmpty {
                    CardWalletStack(
                        entries: entries(for: visibleActiveCards),
                        ownerName: { ownersService.ownerName(for: $0) },
                        busyCardID: markingPaidCardID,
                        openCardID: $openCardID,
                        onOpenPayments: { paymentsCard = $0 },
                        onMarkPaid: { cardPendingPayment = $0 },
                        onEdit: { editingCard = $0 },
                        onDelete: requestDeletion
                    )
                    .padding(.horizontal, 16)
                }

                if !visibleInactiveCards.isEmpty {
                    inactiveSection
                }
            }
        }
    }

    private var inactiveSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                Haptics.selection()
                withAnimation(motion) { showsInactiveSection.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text(
                        String(
                            format: String(localized: "cards_inactive_section"),
                            visibleInactiveCards.count
                        )
                    )
                    .font(.subheadline.weight(.semibold))

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(showsInactiveSection ? 90 : 0))

                    Spacer(minLength: 0)
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showsInactiveSection {
                CardWalletStack(
                    entries: entries(for: visibleInactiveCards),
                    ownerName: { ownersService.ownerName(for: $0) },
                    busyCardID: markingPaidCardID,
                    openCardID: $openInactiveCardID,
                    onOpenPayments: { paymentsCard = $0 },
                    onMarkPaid: { cardPendingPayment = $0 },
                    onEdit: { editingCard = $0 },
                    onDelete: requestDeletion
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal, 16)
    }

    private var loadingPlaceholder: some View {
        VStack(spacing: 16) {
            ForEach(0..<2, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .aspectRatio(CreditCardView.aspectRatio, contentMode: .fit)
            }
        }
        .padding(.horizontal, 16)
        .accessibilityHidden(true)
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.primaryAction)

            VStack(spacing: 8) {
                Text("cards_empty_title")
                    .font(.title3.weight(.semibold))

                Text("cards_empty_message")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
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

    private var noResultsState: some View {
        VStack(spacing: 14) {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            Text("cards_no_results_title")
                .font(.subheadline.weight(.medium))

            Button("cards_clear_filters") {
                Haptics.selection()
                withAnimation(motion) { query.clearRefinements() }
            }
            .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.amberStateForeground)

                Text(errorMessage)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("action_retry") {
                    Task { await refreshCardsScreen() }
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

    @ViewBuilder
    private var undoBar: some View {
        if let pendingDeletion {
            HStack(spacing: 12) {
                Image(systemName: "trash.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(
                    String(
                        format: String(localized: "cards_deleted_toast"),
                        pendingDeletion.card.name
                    )
                )
                .font(.subheadline)
                .lineLimit(1)

                Spacer(minLength: 8)

                Button("action_undo") { undoDeletion() }
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.defaultBorder, lineWidth: 1)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Payments

    private var showPaymentConfirmation: Binding<Bool> {
        Binding(
            get: { cardPendingPayment != nil },
            set: { if !$0 { cardPendingPayment = nil } }
        )
    }

    private func quickPaymentConfirmationMessage(for card: APICard) -> String {
        PaymentConfirmationCopy.message(for: paymentsService.status(for: card.id))
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

    // MARK: - Deletion with undo

    private struct PendingCardDeletion {
        let card: APICard
        let timer: Task<Void, Never>
    }

    private func requestDeletion(of card: APICard) {
        commitPendingDeletion()
        Haptics.warning()

        let timer = Task { @MainActor in
            try? await Task.sleep(for: Self.undoWindow)
            guard !Task.isCancelled else { return }
            await confirmDeletion(of: card)
        }

        withAnimation(motion) {
            pendingDeletion = PendingCardDeletion(card: card, timer: timer)
        }
    }

    private func undoDeletion() {
        guard let pendingDeletion else { return }
        pendingDeletion.timer.cancel()
        Haptics.selection()
        withAnimation(motion) { self.pendingDeletion = nil }
    }

    /// Flushes an in-flight undo so a second deletion never overwrites the first one.
    private func commitPendingDeletion() {
        guard let pendingDeletion else { return }
        pendingDeletion.timer.cancel()
        self.pendingDeletion = nil

        let card = pendingDeletion.card
        Task { await confirmDeletion(of: card) }
    }

    private func confirmDeletion(of card: APICard) async {
        if pendingDeletion?.card.id == card.id {
            withAnimation(motion) { pendingDeletion = nil }
        }

        guard await cardsService.deleteCard(id: card.id) else { return }

        await paymentsService.fetchDashboard()
        Haptics.success()
    }

    // MARK: - Loading

    private func loadOwnersIfNeeded() async {
        guard !ownersService.hasLoaded else { return }
        await ownersService.fetchOwners()
    }

    private func refreshCardsScreen() async {
        async let cards: Void = cardsService.fetchCards(silentUnlessEmpty: false)
        async let dashboard: Void = paymentsService.fetchDashboard(silentUnlessEmpty: false)
        _ = await (cards, dashboard)
    }
}

#Preview {
    CardsView()
        .environment(CardsAPIService())
        .environment(PaymentsAPIService())
        .environment(OwnersAPIService())
        .environment(AppNavigation())
}
