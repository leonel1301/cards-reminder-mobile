import SwiftUI
import UIKit

struct CreditCardView: View {
    static let aspectRatio: CGFloat = 1.586

    let card: APICard
    var status: APICardStatus?
    var ownerName: String?
    var statusRevealDelay: Double = 0
    var isElevated: Bool = false
    var onMarkPaid: (() -> Void)?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var contentColor: Color {
        card.color.isLightForegroundPreferred ? Color.black.opacity(0.82) : .white
    }

    private var secondaryContentColor: Color {
        card.color.isLightForegroundPreferred ? Color.black.opacity(0.55) : .white.opacity(0.78)
    }

    private var isPaidThisCycle: Bool {
        status?.isPaidThisCycle == true
    }

    private var showsLiveStatus: Bool {
        card.isActive && status != nil
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            cardBackground

            VStack(alignment: .leading, spacing: 0) {
                headerRow

                Spacer(minLength: 12)

                infoBlock

                Spacer(minLength: 12)

                footerRow
            }
            .padding(18)
            .foregroundStyle(contentColor)

            if !card.isActive {
                inactiveBadge
            }
        }
        .modifier(CreditCardFrame(usesFixedRatio: !dynamicTypeSize.isAccessibilitySize))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: shadowColor, radius: isElevated ? 16 : 10, y: isElevated ? 10 : 6)
        .opacity(card.isActive ? 1 : 0.72)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(card.name))
    }

    private var shadowColor: Color {
        card.color.opacity(card.isActive ? (isElevated ? 0.38 : 0.28) : 0.12)
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(alignment: .top, spacing: 12) {
            chipView

            VStack(alignment: .leading, spacing: 1) {
                Text(card.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let subtitle = headerSubtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(secondaryContentColor)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                if let status, card.isActive {
                    CardStatusBadge(status: status)
                        .transition(SmoothRevealAnimation.transition(reduceMotion: reduceMotion))
                        .animation(
                            SmoothRevealAnimation.motion(reduceMotion: reduceMotion)?
                                .delay(statusRevealDelay),
                            value: status
                        )
                }

                if card.isActive, onMarkPaid != nil, !isPaidThisCycle {
                    markPaidButton
                }
            }
        }
    }

    private var headerSubtitle: String? {
        let issuer = card.issuer?.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = [issuer, ownerName].compactMap { value -> String? in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var markPaidButton: some View {
        Image(systemName: "checkmark")
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.emeraldStateForeground)
            .frame(width: 28, height: 28)
            .background(Color.white.opacity(0.95), in: Circle())
            .shadow(color: .black.opacity(0.14), radius: 3, y: 1)
            .contentShape(Circle())
            .highPriorityGesture(TapGesture().onEnded { onMarkPaid?() })
            .accessibilityLabel(Text("payments_mark_paid"))
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Middle block

    @ViewBuilder
    private var infoBlock: some View {
        if showsLiveStatus, let status {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(countdownHeadline(for: status))
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(cycleDatesLabel(for: status))
                        .font(.caption2)
                        .foregroundStyle(secondaryContentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                CardCycleProgressBar(status: status, tint: contentColor)
            }
        } else {
            Text(billingDaysLabel)
                .font(.caption.weight(.medium))
                .foregroundStyle(secondaryContentColor)
        }
    }

    private func countdownHeadline(for status: APICardStatus) -> String {
        if status.isPaidThisCycle {
            return String(localized: "card_countdown_paid")
        }

        let overdueDays = max(status.daysOverdue, -min(status.daysUntilPayment, 0))
        if overdueDays == 1 {
            return String(localized: "card_countdown_overdue_yesterday")
        }
        if overdueDays > 1 {
            return String(format: String(localized: "card_countdown_overdue"), overdueDays)
        }

        switch status.daysUntilPayment {
        case 0: return String(localized: "card_countdown_today")
        case 1: return String(localized: "card_countdown_tomorrow")
        default: return String(format: String(localized: "card_countdown_days"), status.daysUntilPayment)
        }
    }

    private func cycleDatesLabel(for status: APICardStatus) -> String {
        String(
            format: String(localized: "card_cycle_dates"),
            shortDate(status.cycleEnd),
            shortDate(status.paymentDueDate)
        )
    }

    private func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    private var billingDaysLabel: String {
        String(
            format: String(localized: "billing_cut_payment"),
            card.billingCycleDay,
            card.paymentDueDay
        )
    }

    // MARK: - Footer

    private var footerRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(formattedCardNumber)
                .font(.system(.footnote, design: .monospaced).weight(.medium))
                .tracking(1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 8)

            if hasNotes {
                Image(systemName: "note.text")
                    .font(.caption2)
                    .foregroundStyle(secondaryContentColor)
                    .accessibilityLabel(Text("card_has_notes"))
            }

            if showsLiveStatus {
                Text(billingDaysLabel)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(secondaryContentColor)
                    .lineLimit(1)
            }
        }
    }

    private var hasNotes: Bool {
        card.notes?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var formattedCardNumber: String {
        guard card.lastFourDigits != "0000" else { return "•••• •••• •••• ••••" }
        return "•••• •••• •••• \(card.lastFourDigits)"
    }

    // MARK: - Decoration

    private var cardBackground: some View {
        ZStack {
            Rectangle()
                .fill(card.color)

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.22),
                            .clear,
                            .black.opacity(0.18),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Circle()
                .fill(.white.opacity(0.08))
                .frame(width: 180, height: 180)
                .offset(x: 120, y: -60)

            Circle()
                .fill(.black.opacity(0.06))
                .frame(width: 140, height: 140)
                .offset(x: -100, y: 80)
        }
        .accessibilityHidden(true)
    }

    private var chipView: some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.92, green: 0.84, blue: 0.55),
                        Color(red: 0.78, green: 0.66, blue: 0.32),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 34, height: 25)
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(.black.opacity(0.12), lineWidth: 0.5)
            }
            .accessibilityHidden(true)
    }

    private var inactiveBadge: some View {
        Text("card_inactive_badge")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
            .padding(12)
    }
}

/// Keeps the ISO card proportion at regular text sizes, and lets the card grow with the
/// content once the user picks an accessibility text size.
private struct CreditCardFrame: ViewModifier {
    let usesFixedRatio: Bool

    func body(content: Content) -> some View {
        if usesFixedRatio {
            content.aspectRatio(CreditCardView.aspectRatio, contentMode: .fit)
        } else {
            content.frame(maxWidth: .infinity)
        }
    }
}

/// Progress of the current cycle, from the day it opened to the payment due date,
/// with a tick marking the statement cut.
private struct CardCycleProgressBar: View {
    let status: APICardStatus
    let tint: Color

    private var totalSpan: TimeInterval {
        status.paymentDueDate.timeIntervalSince(status.cycleStart)
    }

    private var progress: Double {
        guard totalSpan > 0 else { return 0 }
        let elapsed = Date.now.timeIntervalSince(status.cycleStart)
        return min(max(elapsed / totalSpan, 0), 1)
    }

    private var cutFraction: Double? {
        guard totalSpan > 0 else { return nil }
        let fraction = status.cycleEnd.timeIntervalSince(status.cycleStart) / totalSpan
        guard fraction > 0.03, fraction < 0.97 else { return nil }
        return fraction
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(tint.opacity(0.18))

                Capsule()
                    .fill(tint.opacity(0.85))
                    .frame(width: max(4, proxy.size.width * progress))

                if let cutFraction {
                    Capsule()
                        .fill(tint.opacity(0.6))
                        .frame(width: 2)
                        .offset(x: proxy.size.width * cutFraction)
                }
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

private extension Color {
    var isLightForegroundPreferred: Bool {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let luminance = (0.299 * red) + (0.587 * green) + (0.114 * blue)
        return luminance > 0.62
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            CreditCardView(
                card: APICard(
                    id: UUID(),
                    userID: UUID(),
                    ownerID: UUID(),
                    name: "Visa Banco X",
                    lastFourDigits: "4532",
                    issuer: "Banco X",
                    billingCycleDay: 15,
                    paymentDueDay: 5,
                    colorHex: "6366F1",
                    notes: "Cuota del auto",
                    isActive: true,
                    createdAt: .now,
                    updatedAt: .now
                ),
                status: APICardStatus(
                    status: "urgent",
                    cycleStart: .now.addingTimeInterval(-14 * 86_400),
                    cycleEnd: .now.addingTimeInterval(-2 * 86_400),
                    paymentDueDate: .now.addingTimeInterval(2 * 86_400),
                    daysUntilPayment: 2,
                    daysOverdue: 0,
                    optimalPurchaseDay: 16,
                    isOptimalPurchaseDay: false,
                    isPaidThisCycle: false
                ),
                ownerName: "María",
                isElevated: true,
                onMarkPaid: {}
            )

            CreditCardView(
                card: APICard(
                    id: UUID(),
                    userID: UUID(),
                    ownerID: UUID(),
                    name: "Falabella",
                    lastFourDigits: "8821",
                    issuer: "CMR",
                    billingCycleDay: 9,
                    paymentDueDay: 5,
                    colorHex: "22C55E",
                    notes: nil,
                    isActive: false,
                    createdAt: .now,
                    updatedAt: .now
                )
            )
        }
        .padding()
    }
}
