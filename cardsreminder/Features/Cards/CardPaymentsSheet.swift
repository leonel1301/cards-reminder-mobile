import SwiftUI

struct CardPaymentsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(PaymentsAPIService.self) private var paymentsService
    @Environment(CardsAPIService.self) private var cardsService

    let card: APICard

    @State private var payments: [APIPayment] = []
    @State private var status: APICardStatus?
    @State private var currentCycle: APICardCycle?
    @State private var optimalPurchaseDays: [Date] = []
    @State private var paymentNotes = ""
    @State private var isLoading = true
    @State private var isMarkingPaid = false
    @State private var loadError: String?
    @State private var showEditForm = false

    private var displayCard: APICard {
        cardsService.cards.first { $0.id == card.id } ?? card
    }

    private var isInitialLoading: Bool {
        isLoading && status == nil && currentCycle == nil && loadError == nil
    }

    private var showsDistinctCurrentCycle: Bool {
        guard let status, let currentCycle else { return false }
        return !isSameCycle(
            start: status.cycleStart,
            end: status.cycleEnd,
            otherStart: currentCycle.start,
            otherEnd: currentCycle.end
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if isInitialLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    contentScrollView
                }
            }
            .navigationTitle(displayCard.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action_cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showEditForm = true
                    } label: {
                        Label("screen_edit_card_title", systemImage: "pencil")
                    }
                }
            }
            .sheet(isPresented: $showEditForm, onDismiss: {
                Task { await loadData() }
            }) {
                CardFormView(mode: .edit(displayCard))
            }
            .task {
                await loadData()
            }
        }
    }

    private var contentScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let loadError {
                    Text(loadError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                if let status {
                    pendingPaymentSection(status)
                }

                if showsDistinctCurrentCycle, let currentCycle {
                    currentCycleSection(currentCycle)
                }

                if !optimalPurchaseDays.isEmpty {
                    optimalDaysSection
                }

                historySection
            }
            .padding(16)
        }
        .refreshable {
            await loadData()
        }
    }

    @ViewBuilder
    private func pendingPaymentSection(_ status: APICardStatus) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("payments_pending_payment_title")
                        .font(.headline)

                    Text(cycleDateRangeLabel(start: status.cycleStart, end: status.cycleEnd))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
                CardStatusBadge(status: status)
            }

            VStack(alignment: .leading, spacing: 8) {
                statusRow(
                    label: String(localized: "payments_due_date"),
                    value: status.paymentDueDate.formatted(date: .abbreviated, time: .omitted)
                )

                if status.isPaidThisCycle {
                    Label("payments_paid_this_cycle", systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.emeraldStateForeground)
                } else if status.daysOverdue > 0 {
                    Text(String(format: String(localized: "payments_days_overdue"), status.daysOverdue))
                        .font(.subheadline)
                        .foregroundStyle(Color.redStateForeground)
                } else if status.daysUntilPayment > 0 {
                    Text(String(format: String(localized: "payments_days_until"), status.daysUntilPayment))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !status.isPaidThisCycle {
                    markPaidControls(for: status)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    @ViewBuilder
    private func currentCycleSection(_ cycle: APICardCycle) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("payments_current_cycle_title")
                    .font(.headline)

                Text(cycleDateRangeLabel(start: cycle.start, end: cycle.end))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                statusRow(
                    label: String(localized: "payments_due_date"),
                    value: cycle.paymentDue.formatted(date: .abbreviated, time: .omitted)
                )

                Text("payments_current_cycle_footer")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private var optimalDaysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("payments_optimal_days_title")
                .font(.headline)

            if status?.isOptimalPurchaseDay == true {
                Label("payments_optimal_today", systemImage: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(Color.violetStateForeground)
            }

            FlowLayout(spacing: 8) {
                ForEach(optimalPurchaseDays, id: \.self) { date in
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.violetStateBackground)
                        .foregroundStyle(Color.violetStateForeground)
                        .clipShape(Capsule())
                }
            }
        }
    }

    @ViewBuilder
    private func markPaidControls(for status: APICardStatus) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .padding(.vertical, 4)

            Text("payments_mark_section_title")
                .font(.subheadline.weight(.semibold))

            if showsDistinctCurrentCycle {
                Text(
                    String(
                        format: String(localized: "payments_mark_cycle_hint"),
                        cycleDateRangeLabel(start: status.cycleStart, end: status.cycleEnd)
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            paymentNotesField

            Button {
                Task { await markPaid() }
            } label: {
                HStack {
                    if isMarkingPaid {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.circle")
                        Text("payments_mark_paid")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.primaryAction)
            .disabled(isMarkingPaid)
        }
    }

    private var paymentNotesField: some View {
        TextField("payments_notes_placeholder", text: $paymentNotes, axis: .vertical)
            .lineLimit(2...4)
            .font(.subheadline)
            .textFieldStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 76, alignment: .topLeading)
            .background(Color(.tertiarySystemFill))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.defaultBorder.opacity(0.55), lineWidth: 0.5)
            }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("payments_history_title")
                .font(.headline)

            if payments.isEmpty && !isLoading {
                Text("payments_history_empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else {
                ForEach(payments) { payment in
                    paymentRow(payment)
                }
            }
        }
    }

    private func paymentRow(_ payment: APIPayment) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(payment.cycleEnd.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text(payment.paidAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let notes = payment.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func cycleDateRangeLabel(start: Date, end: Date) -> String {
        let startLabel = start.formatted(date: .abbreviated, time: .omitted)
        let endLabel = end.formatted(date: .abbreviated, time: .omitted)
        return "\(startLabel) – \(endLabel)"
    }

    private func isSameCycle(start: Date, end: Date, otherStart: Date, otherEnd: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(start, inSameDayAs: otherStart)
            && calendar.isDate(end, inSameDayAs: otherEnd)
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private func loadData() async {
        isLoading = true
        loadError = nil
        defer { isLoading = false }

        async let currentCycleTask = paymentsService.fetchCurrentCycle(cardID: card.id)
        async let optimalDaysTask = paymentsService.fetchOptimalPurchaseDays(cardID: card.id)
        async let paymentsTask = paymentsService.fetchPayments(cardID: card.id)

        let currentCycleResponse = await currentCycleTask
        let optimalDaysResponse = await optimalDaysTask
        let paymentsResponse = await paymentsTask

        if currentCycleResponse == nil && optimalDaysResponse == nil && paymentsResponse == nil {
            loadError = String(localized: "error_invalid_response")
            return
        }

        if let currentCycleResponse {
            status = currentCycleResponse.status
            currentCycle = currentCycleResponse.cycle
            updateCardInService(currentCycleResponse.card)
        }

        if let optimalDaysResponse {
            optimalPurchaseDays = optimalDaysResponse.optimalPurchaseDays
            updateCardInService(optimalDaysResponse.card)
        }

        if let paymentsResponse {
            payments = paymentsResponse.payments
            updateCardInService(paymentsResponse.card)
        }
    }

    private func updateCardInService(_ card: APICard) {
        if let index = cardsService.cards.firstIndex(where: { $0.id == card.id }) {
            cardsService.cards[index] = card
        }
    }

    private func markPaid() async {
        isMarkingPaid = true
        defer { isMarkingPaid = false }

        let trimmedNotes = paymentNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = trimmedNotes.isEmpty ? nil : trimmedNotes

        guard let response = await paymentsService.markAsPaid(cardID: card.id, notes: notes) else {
            loadError = paymentsService.errorMessage
            return
        }

        status = response.status
        optimalPurchaseDays = response.optimalPurchaseDays
        updateCardInService(response.card)

        if let refreshed = await paymentsService.fetchCurrentCycle(cardID: card.id) {
            status = refreshed.status
            currentCycle = refreshed.cycle
            updateCardInService(refreshed.card)
        }

        if let refreshed = await paymentsService.fetchPayments(cardID: card.id) {
            payments = refreshed.payments
        }
    }
}

#Preview {
    CardPaymentsSheet(card: APICard(
        id: UUID(),
        userID: UUID(),
        ownerID: UUID(),
        name: "Visa Banco X",
        lastFourDigits: "4532",
        issuer: "BBVA",
        billingCycleDay: 10,
        paymentDueDay: 18,
        colorHex: "6366F1",
        notes: nil,
        isActive: true,
        createdAt: .now,
        updatedAt: .now
    ))
    .environment(PaymentsAPIService())
    .environment(CardsAPIService())
}
