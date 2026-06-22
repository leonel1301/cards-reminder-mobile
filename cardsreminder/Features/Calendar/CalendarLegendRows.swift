import SwiftUI

struct CalendarLegendRows: View {
    let cards: [APICard]
    let billingPeriods: [BillingPeriodInstance]
    let payments: [BillingPeriodInstance]
    @Binding var selection: CalendarSelection?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardColorRow
            billingPeriodRow
            paymentRow
        }
        .padding(.vertical, 12)
    }

    private var cardColorRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("calendar_legend_cards")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(cards) { card in
                        cardTag(card)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func cardTag(_ card: APICard) -> some View {
        let isSelected = isCardSelected(card)

        return Button {
            toggleSelection(.card(card.id))
        } label: {
            HStack(spacing: 5) {
                Circle()
                    .fill(card.color)
                    .frame(width: 8, height: 8)

                Text(card.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isSelected ? card.color.opacity(0.18) : Color(.tertiarySystemFill))
            .foregroundStyle(isSelected ? card.color : .primary)
            .clipShape(Capsule())
            .overlay {
                Capsule()
                    .stroke(isSelected ? card.color.opacity(0.55) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var billingPeriodRow: some View {
        legendSection(title: String(localized: "calendar_legend_billing_periods")) {
            ForEach(billingPeriods) { period in
                selectableChip(isSelected: selection == .billingPeriod(period.id)) {
                    toggleSelection(.billingPeriod(period.id))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: period.cardColorHex).opacity(0.75))
                                .frame(width: 28, height: 5)
                            Text(period.periodLabel)
                                .font(.subheadline.weight(.medium))
                        }
                        Text(period.cardName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var paymentRow: some View {
        legendSection(title: String(localized: "calendar_legend_payments")) {
            ForEach(payments) { period in
                selectableChip(isSelected: selection == .payment(period.id)) {
                    toggleSelection(.payment(period.id))
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: period.cardColorHex))
                                .frame(width: 10, height: 10)
                                .overlay {
                                    Circle().stroke(.white, lineWidth: 1)
                                }
                            Text(period.paymentSummaryLabel)
                                .font(.subheadline.weight(.medium))
                        }
                        Text(period.paymentDetailLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
        }
    }

    private func legendSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    content()
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func selectableChip<Label: View>(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
    }

    private func isCardSelected(_ card: APICard) -> Bool {
        if case .card(let id) = selection {
            return id == card.id
        }
        return false
    }

    private func toggleSelection(_ newSelection: CalendarSelection) {
        Haptics.selection()
        if selection == newSelection {
            selection = nil
        } else {
            selection = newSelection
        }
    }
}
