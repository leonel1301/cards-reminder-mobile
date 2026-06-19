import SwiftUI

struct TimelineEventRow: View {
    let event: TimelineEvent
    let isLast: Bool
    let revealDelay: Double
    var isRevealed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            timelineRail

            eventCard
                .opacity(isRevealed ? 1 : 0)
                .scaleEffect(isRevealed ? 1 : 0.94, anchor: .leading)
                .offset(x: isRevealed ? 0 : 12)
                .animation(SmoothRevealAnimation.motion.delay(revealDelay), value: isRevealed)
        }
    }

    private var timelineRail: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(event.kind.backgroundColor)
                    .frame(width: 36, height: 36)

                Image(systemName: event.kind.iconName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(event.kind.foregroundColor)
            }
            .opacity(isRevealed ? 1 : 0)
            .scaleEffect(isRevealed ? 1 : 0.6)
            .animation(SmoothRevealAnimation.motion.delay(revealDelay), value: isRevealed)

            if !isLast {
                Rectangle()
                    .fill(Color.defaultBorder)
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
                    .padding(.vertical, 4)
                    .opacity(isRevealed ? 1 : 0)
                    .animation(SmoothRevealAnimation.motion.delay(revealDelay + 0.05), value: isRevealed)
            }
        }
        .frame(width: 36)
    }

    private var eventCard: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.card.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey(event.kind.titleKey))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)

                        Text(event.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 8)

                    CardStatusBadge(status: event.status)
                }

                HStack(spacing: 8) {
                    Text(event.card.name)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)

                    Text(event.card.maskedNumber)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.defaultBorder.opacity(0.65), lineWidth: 0.5)
        }
    }
}

#Preview {
    let card = APICard(
        id: UUID(),
        userID: UUID(),
        ownerID: UUID(),
        name: "Visa Oro",
        lastFourDigits: "4532",
        issuer: "Banco X",
        billingCycleDay: 15,
        paymentDueDay: 5,
        colorHex: "6366F1",
        notes: nil,
        isActive: true,
        createdAt: .now,
        updatedAt: .now
    )

    VStack(spacing: 14) {
        TimelineEventRow(
            event: TimelineEvent(
                id: "1",
                card: card,
                status: APICardStatus(
                    status: "urgent",
                    cycleStart: .now,
                    cycleEnd: .now,
                    paymentDueDate: .now,
                    daysUntilPayment: 2,
                    daysOverdue: 0,
                    optimalPurchaseDay: 16,
                    isOptimalPurchaseDay: false,
                    isPaidThisCycle: false
                ),
                kind: .urgent,
                sortOrder: 0
            ),
            isLast: true,
            revealDelay: 0,
            isRevealed: true
        )

        TimelineEventRow(
            event: TimelineEvent(
                id: "2",
                card: card,
                status: APICardStatus(
                    status: "optimal_day",
                    cycleStart: .now,
                    cycleEnd: .now,
                    paymentDueDate: .now,
                    daysUntilPayment: 28,
                    daysOverdue: 0,
                    optimalPurchaseDay: 16,
                    isOptimalPurchaseDay: true,
                    isPaidThisCycle: false
                ),
                kind: .optimalToday,
                sortOrder: 1
            ),
            isLast: true,
            revealDelay: 0.05,
            isRevealed: true
        )
    }
    .padding()
}
