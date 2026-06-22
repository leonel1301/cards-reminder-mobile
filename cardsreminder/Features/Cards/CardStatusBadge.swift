import SwiftUI

struct CardStatusBadge: View {
    let status: APICardStatus

    private var label: LocalizedStringKey {
        switch status.kind {
        case .paid: "card_status_paid"
        case .overdue: "card_status_overdue"
        case .urgent: "card_status_urgent"
        case .dueSoon: "card_status_due_soon"
        case .optimalDay: "card_status_optimal_day"
        case .onTrack: "card_status_on_track"
        }
    }

    private var backgroundColor: Color {
        switch status.kind {
        case .paid: Color.emeraldStateBackground
        case .overdue: Color.redStateBackground
        case .urgent: Color.amberStateBackground
        case .dueSoon: Color.violetStateBackground
        case .optimalDay: Color.violetStateBackground
        case .onTrack: Color.onTrackStateBackground
        }
    }

    private var foregroundColor: Color {
        switch status.kind {
        case .paid: Color.emeraldStateForeground
        case .overdue: Color.redStateForeground
        case .urgent: Color.amberStateForeground
        case .dueSoon: Color.violetStateForeground
        case .optimalDay: Color.violetStateForeground
        case .onTrack: Color.onTrackStateForeground
        }
    }

    var body: some View {
        Text(label)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(foregroundColor)
            .background(backgroundColor)
            .clipShape(Capsule())
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
