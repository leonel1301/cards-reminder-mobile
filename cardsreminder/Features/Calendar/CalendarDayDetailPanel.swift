import SwiftUI

/// What happens on the selected day, sitting right under the grid so the
/// calendar itself stays visible.
struct CalendarDayDetailPanel: View {
    let date: Date
    let isToday: Bool
    let content: CalendarDayContent
    var showsHeader: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if showsHeader {
                header
            }

            if content.isEmpty {
                Text("calendar_day_empty")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                if !content.payments.isEmpty {
                    section(titleKey: "calendar_day_payments_title") {
                        ForEach(content.payments) { payment in
                            paymentRow(payment)
                        }
                    }
                }

                if !content.optimalPurchaseCardNames.isEmpty {
                    optimalPurchaseRow
                }

                if !content.periods.isEmpty {
                    section(titleKey: "calendar_day_periods_title") {
                        ForEach(content.periods) { period in
                            periodRow(period)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.defaultBorder, lineWidth: 1)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                .font(.headline)

            if isToday {
                Text("calendar_action_today")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.primaryAction)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primaryAction.opacity(0.14), in: Capsule())
            }

            Spacer(minLength: 0)
        }
    }

    private func section<Content: View>(
        titleKey: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(titleKey)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            content()
        }
    }

    private func paymentRow(_ payment: CalendarPaymentMark) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(payment.color)
                .frame(width: 9, height: 9)
                .overlay { Circle().strokeBorder(payment.state.accentColor, lineWidth: 1.5) }
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }

            VStack(alignment: .leading, spacing: 2) {
                Text(payment.cardName)
                    .font(.subheadline.weight(.medium))

                Text(payment.periodLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(payment.state.labelKey)
                .font(.caption2.weight(.bold))
                .foregroundStyle(payment.state.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(payment.state.badgeBackground, in: Capsule())
        }
        .accessibilityElement(children: .combine)
    }

    private func periodRow(_ period: CalendarPeriodMark) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Capsule()
                .fill(period.color.opacity(0.75))
                .frame(width: 18, height: 5)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] + 1 }

            VStack(alignment: .leading, spacing: 2) {
                Text(period.cardName)
                    .font(.subheadline.weight(.medium))

                Text(period.periodLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if period.isCutDay {
                Text("calendar_cut_badge")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.violetStateForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.violetStateBackground, in: Capsule())
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var optimalPurchaseRow: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "sparkles")
                .font(.subheadline)
                .foregroundStyle(Color.violetStateForeground)

            VStack(alignment: .leading, spacing: 2) {
                Text("calendar_day_optimal_title")
                    .font(.subheadline.weight(.medium))

                Text(
                    String(
                        format: String(localized: "calendar_day_optimal_message"),
                        content.optimalPurchaseCardNames.formatted(.list(type: .and))
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.violetStateBackground.opacity(0.5), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CalendarDayDetailPanel(
        date: .now,
        isToday: true,
        content: CalendarDayContent(
            periods: [
                CalendarPeriodMark(
                    id: "1",
                    cardID: UUID(),
                    cardName: "Visa Banco X",
                    colorHex: "6366F1",
                    periodLabel: "16 sept – 15 oct",
                    isSegmentStart: false,
                    isSegmentEnd: true,
                    isCutDay: true
                )
            ],
            payments: [
                CalendarPaymentMark(
                    id: "2",
                    cardID: UUID(),
                    cardName: "Falabella CMR",
                    colorHex: "22C55E",
                    periodLabel: "10 ago – 9 sept",
                    state: .overdue
                )
            ],
            optimalPurchaseCardNames: ["Visa Banco X"]
        )
    )
    .padding()
    .background(Color.appBackground)
}
