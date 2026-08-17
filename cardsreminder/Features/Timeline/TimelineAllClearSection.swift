import SwiftUI

/// Cards that need nothing today, folded away by default so they do not compete
/// with the ones that do.
struct TimelineAllClearSection: View {
    let events: [TimelineEvent]
    @Binding var isExpanded: Bool
    let onOpenHistory: (TimelineEvent) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if isExpanded {
                VStack(spacing: 8) {
                    ForEach(events) { event in
                        TimelineCompactEventRow(event: event) {
                            onOpenHistory(event)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var header: some View {
        Button {
            Haptics.selection()
            withAnimation(SmoothRevealAnimation.motion(reduceMotion: reduceMotion)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.emeraldStateForeground)

                Text("timeline_section_all_clear")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(
                    String(
                        format: String(localized: "timeline_all_clear_count"),
                        events.count
                    )
                )
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 0 : -90))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isExpanded ? [.isButton, .isSelected] : .isButton)
    }
}

private struct TimelineAllClearSectionPreview: View {
    @State private var isExpanded = false

    private let events: [TimelineEvent] = ["Visa Oro", "CMR"].enumerated().map { index, name in
        let card = APICard(
            id: UUID(),
            userID: UUID(),
            ownerID: UUID(),
            name: name,
            lastFourDigits: "000\(index)",
            issuer: nil,
            billingCycleDay: 15,
            paymentDueDay: 5,
            colorHex: "6366F1",
            notes: nil,
            isActive: true,
            createdAt: .now,
            updatedAt: .now
        )

        return TimelineEvent(
            id: "\(index)",
            card: card,
            status: APICardStatus(
                status: "paid",
                cycleStart: .now,
                cycleEnd: .now,
                paymentDueDate: .now,
                daysUntilPayment: 20,
                daysOverdue: 0,
                optimalPurchaseDay: 16,
                isOptimalPurchaseDay: false,
                isPaidThisCycle: true
            ),
            kind: .paid,
            sortOrder: index
        )
    }

    var body: some View {
        TimelineAllClearSection(events: events, isExpanded: $isExpanded) { _ in }
            .padding()
    }
}

#Preview {
    TimelineAllClearSectionPreview()
}
