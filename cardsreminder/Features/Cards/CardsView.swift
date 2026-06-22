import SwiftUI

struct CardsView: View {
    @Environment(CardsAPIService.self) private var cardsService
    @Environment(PaymentsAPIService.self) private var paymentsService
    @State private var showCreateForm = false
    @State private var editingCard: APICard?
    @State private var paymentsCard: APICard?
    @State private var cardPendingDelete: APICard?
    @State private var cardPendingPayment: APICard?
    @State private var markingPaidCardID: UUID?
    @State private var deletingCardID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            screenTitle

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let summary = paymentsService.summary, summary.hasAttentionItems {
                        DashboardSummaryBanner(summary: summary)
                            .padding(.horizontal, 16)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    addButton

                    if let errorMessage = visibleErrorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 16)
                    }

                    if cardsService.cards.isEmpty && !cardsService.isLoading {
                        emptyState
                    } else {
                        cardsList
                    }
                }
                .padding(.bottom, 16)
                .animation(SmoothRevealAnimation.motion, value: paymentsService.dashboardRevision)
            }
        }
        .safeAreaPadding(.bottom)
        .overlay {
            if cardsService.isLoading && cardsService.cards.isEmpty {
                ProgressView()
            }
        }
        .refreshable {
            await refreshCardsScreen()
        }
        .sheet(isPresented: $showCreateForm, onDismiss: {
            Task { await refreshCardsScreen() }
        }) {
            CardFormView(mode: .create)
        }
        .sheet(item: $editingCard, onDismiss: {
            Task { await refreshCardsScreen() }
        }) { card in
            CardFormView(mode: .edit(card))
        }
        .sheet(item: $paymentsCard) { card in
            CardPaymentsSheet(card: card)
        }
        .alert("delete_card_confirm_title", isPresented: showDeleteConfirmation) {
            Button("action_cancel", role: .cancel) {
                cardPendingDelete = nil
            }
            Button("action_delete", role: .destructive) {
                guard let card = cardPendingDelete else { return }
                cardPendingDelete = nil
                Task { await deleteCard(card) }
            }
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

    private var visibleErrorMessage: String? {
        if let message = cardsService.errorMessage, cardsService.cards.isEmpty {
            return message
        }
        if let message = paymentsService.errorMessage, !paymentsService.hasCachedDashboard {
            return message
        }
        return nil
    }

    private var showDeleteConfirmation: Binding<Bool> {
        Binding(
            get: { cardPendingDelete != nil },
            set: { if !$0 { cardPendingDelete = nil } }
        )
    }

    private var showPaymentConfirmation: Binding<Bool> {
        Binding(
            get: { cardPendingPayment != nil },
            set: { if !$0 { cardPendingPayment = nil } }
        )
    }

    private func quickPaymentConfirmationMessage(for card: APICard) -> String {
        guard let status = paymentsService.status(for: card.id) else {
            return String(localized: "payments_quick_confirm_message_fallback")
        }

        let period = cycleDateRangeLabel(start: status.cycleStart, end: status.cycleEnd)
        return String(format: String(localized: "payments_quick_confirm_message"), period)
    }

    private func cycleDateRangeLabel(start: Date, end: Date) -> String {
        let startLabel = start.formatted(date: .abbreviated, time: .omitted)
        let endLabel = end.formatted(date: .abbreviated, time: .omitted)
        return "\(startLabel) – \(endLabel)"
    }

    private var screenTitle: some View {
        Text("screen_cards_title")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            .background(Color(.systemBackground))
    }

    private var addButton: some View {
        Button {
            Haptics.lightImpact()
            showCreateForm = true
        } label: {
            Label("action_add_card", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("cards_empty_title")
                .font(.subheadline.weight(.medium))
            Text("cards_empty_message")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }

    private var cardsList: some View {
        VStack(spacing: 16) {
            ForEach(Array(cardsService.cards.enumerated()), id: \.element.id) { index, card in
                CreditCardView(
                    card: card,
                    status: paymentsService.status(for: card.id),
                    statusRevealDelay: SmoothRevealAnimation.staggerDelay(for: index),
                    onOpenPayments: {
                        Haptics.lightImpact()
                        paymentsCard = card
                    },
                    onMarkPaid: card.isActive ? {
                        Haptics.lightImpact()
                        cardPendingPayment = card
                    } : nil,
                    onEdit: { editingCard = card },
                    onDelete: { cardPendingDelete = card }
                )
                .scaleEffect(deletingCardID == card.id ? 0.92 : 1)
                .opacity(deletingCardID == card.id ? 0 : 1)
                .blur(radius: deletingCardID == card.id ? 6 : 0)
                .overlay {
                    if deletingCardID == card.id {
                        deletingOverlay
                    } else if markingPaidCardID == card.id {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .overlay { ProgressView() }
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: SmoothRevealAnimation.sectionTransition,
                        removal: .opacity
                            .combined(with: .scale(scale: 0.88))
                            .combined(with: .move(edge: .trailing))
                    )
                )
            }
        }
        .padding(.horizontal, 16)
        .animation(SmoothRevealAnimation.motion, value: cardsService.contentRevision)
        .animation(SmoothRevealAnimation.motion, value: deletingCardID)
    }

    private var deletingOverlay: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.black.opacity(0.28))
            .overlay {
                Image(systemName: "trash.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, options: .nonRepeating)
            }
            .transition(.opacity)
    }

    private func refreshCardsScreen() async {
        async let cards: Void = cardsService.fetchCards(silentUnlessEmpty: false)
        async let dashboard: Void = paymentsService.fetchDashboard(silentUnlessEmpty: false)
        _ = await (cards, dashboard)
    }

    private func deleteCard(_ card: APICard) async {
        withAnimation(SmoothRevealAnimation.motion) {
            deletingCardID = card.id
        }

        try? await Task.sleep(nanoseconds: 220_000_000)

        guard await cardsService.deleteCard(id: card.id) else {
            withAnimation(SmoothRevealAnimation.motion) {
                deletingCardID = nil
            }
            return
        }

        deletingCardID = nil
        await paymentsService.fetchDashboard()

        Haptics.success()
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
    CardsView()
        .environment(CardsAPIService())
        .environment(PaymentsAPIService())
}
