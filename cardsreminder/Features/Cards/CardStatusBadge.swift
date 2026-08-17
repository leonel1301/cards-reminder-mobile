import SwiftUI

struct CardStatusBadge: View {
    let status: APICardStatus

    var body: some View {
        Text(status.kind.labelKey)
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(status.kind.foregroundColor)
            .background(status.kind.backgroundColor)
            .clipShape(Capsule())
            .accessibilityLabel(Text(status.kind.labelKey))
    }
}

extension CardPaymentStatusKind {
    var labelKey: LocalizedStringKey {
        switch self {
        case .paid: "card_status_paid"
        case .overdue: "card_status_overdue"
        case .urgent: "card_status_urgent"
        case .dueSoon: "card_status_due_soon"
        case .optimalDay: "card_status_optimal_day"
        case .onTrack: "card_status_on_track"
        }
    }

    var countFormatKey: String.LocalizationValue {
        switch self {
        case .paid: "timeline_summary_paid_count"
        case .overdue: "dashboard_overdue_count"
        case .urgent: "dashboard_urgent_count"
        case .dueSoon: "dashboard_due_soon_count"
        case .optimalDay: "timeline_summary_optimal_count"
        case .onTrack: "dashboard_on_track_count"
        }
    }

    var backgroundColor: Color {
        switch self {
        case .paid: Color.emeraldStateBackground
        case .overdue: Color.redStateBackground
        case .urgent: Color.amberStateBackground
        case .dueSoon, .optimalDay: Color.violetStateBackground
        case .onTrack: Color.onTrackStateBackground
        }
    }

    var foregroundColor: Color {
        switch self {
        case .paid: Color.emeraldStateForeground
        case .overdue: Color.redStateForeground
        case .urgent: Color.amberStateForeground
        case .dueSoon, .optimalDay: Color.violetStateForeground
        case .onTrack: Color.onTrackStateForeground
        }
    }
}

#Preview {
    VStack(spacing: 8) {
        ForEach(["paid", "overdue", "urgent", "due_soon", "optimal_day", "on_track"], id: \.self) { raw in
            CardStatusBadge(status: APICardStatus(
                status: raw,
                cycleStart: .now,
                cycleEnd: .now,
                paymentDueDate: .now,
                daysUntilPayment: 2,
                daysOverdue: 0,
                optimalPurchaseDay: 11,
                isOptimalPurchaseDay: raw == "optimal_day",
                isPaidThisCycle: raw == "paid"
            ))
        }
    }
}
