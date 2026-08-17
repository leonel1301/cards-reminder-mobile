import SwiftUI

struct TimelineEventRow: View {
    let event: TimelineEvent
    let revealDelay: Double
    var isRevealed: Bool
    var isMarkingPaid: Bool
    @Binding var openSwipeID: String?
    let onOpenHistory: () -> Void
    /// `nil` when the event has nothing left to settle.
    let onMarkPaid: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            statusIcon

            // Only the card slides; the status icon stays put.
            SwipeActionRow(
                id: event.id,
                titleKey: "payments_pay_action",
                systemImage: "checkmark.circle.fill",
                tint: Color.emeraldStateForeground,
                isEnabled: onMarkPaid != nil,
                openID: $openSwipeID,
                action: { onMarkPaid?() }
            ) {
                eventCard
            }
        }
        .opacity(isRevealed ? 1 : 0)
        .offset(y: isRevealed ? 0 : 8)
        .animation(revealAnimation, value: isRevealed)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(event.accessibilityLabel))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("payments_view_history"))
        .accessibilityAction { onOpenHistory() }
        .accessibilityActions {
            // The swipe drawer is invisible to VoiceOver, so paying needs its
            // own custom action.
            if let onMarkPaid {
                Button("payments_mark_paid", action: onMarkPaid)
            }
        }
    }

    private var revealAnimation: Animation? {
        guard !reduceMotion else { return nil }
        return SmoothRevealAnimation.motion.delay(revealDelay)
    }

    private var statusIcon: some View {
        ZStack {
            Circle()
                .fill(event.kind.backgroundColor)
                .frame(width: 36, height: 36)

            Image(systemName: event.kind.iconName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(event.kind.foregroundColor)
        }
    }

    private var eventCard: some View {
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(event.card.color)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 10) {
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

                footerRow
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
        .overlay {
            if isMarkingPaid {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay { ProgressView() }
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(perform: onOpenHistory)
    }

    private var footerRow: some View {
        HStack(spacing: 8) {
            Text(event.card.name)
                .font(.caption.weight(.medium))
                .lineLimit(1)

            Text(event.card.maskedNumber)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer(minLength: 8)

            if let onMarkPaid {
                Button(action: onMarkPaid) {
                    Label("payments_pay_action", systemImage: "checkmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(Color.emeraldStateForeground)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.emeraldStateBackground, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityHidden(true)
            }
        }
    }
}

/// One-line variant for cards that need nothing, so they take up as little room
/// as possible next to the ones that do.
struct TimelineCompactEventRow: View {
    let event: TimelineEvent
    let onOpenHistory: () -> Void

    var body: some View {
        Button(action: onOpenHistory) {
            HStack(spacing: 12) {
                Image(systemName: event.kind.iconName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(event.kind.foregroundColor)
                    .frame(width: 24, height: 24)
                    .background(event.kind.backgroundColor, in: Circle())

                Text(event.card.name)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(event.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(event.accessibilityLabel))
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

    let urgentStatus = APICardStatus(
        status: "urgent",
        cycleStart: .now,
        cycleEnd: .now,
        paymentDueDate: .now,
        daysUntilPayment: 2,
        daysOverdue: 0,
        optimalPurchaseDay: 16,
        isOptimalPurchaseDay: false,
        isPaidThisCycle: false
    )

    let paidStatus = APICardStatus(
        status: "paid",
        cycleStart: .now,
        cycleEnd: .now,
        paymentDueDate: .now,
        daysUntilPayment: 28,
        daysOverdue: 0,
        optimalPurchaseDay: 16,
        isOptimalPurchaseDay: false,
        isPaidThisCycle: true
    )

    VStack(spacing: 14) {
        TimelineEventRow(
            event: TimelineEvent(id: "1", card: card, status: urgentStatus, kind: .urgent, sortOrder: 0),
            revealDelay: 0,
            isRevealed: true,
            isMarkingPaid: false,
            openSwipeID: .constant(nil),
            onOpenHistory: {},
            onMarkPaid: {}
        )

        TimelineCompactEventRow(
            event: TimelineEvent(id: "2", card: card, status: paidStatus, kind: .paid, sortOrder: 1),
            onOpenHistory: {}
        )
    }
    .padding()
}
