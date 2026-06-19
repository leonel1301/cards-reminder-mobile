import SwiftUI

struct TimelineFeaturedCard: View {
    let card: APICard
    let status: APICardStatus
    let revealDelay: Double
    var isRevealed: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "creditcard.and.badge.checkmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.violetStateForeground)

                Text("timeline_featured_spending_title")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.violetStateForeground)
            }

            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(card.color)
                        .frame(width: 56, height: 36)

                    Image(systemName: "creditcard.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.name)
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(card.maskedNumber)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)

                    Text(String(format: String(localized: "payments_days_until"), status.daysUntilPayment))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.violetStateForeground)
                }

                Spacer(minLength: 0)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.violetStateBackground.opacity(0.95),
                            Color.violetStateBackground.opacity(0.55),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.violetStateForeground.opacity(0.18), lineWidth: 1)
        }
        .opacity(isRevealed ? 1 : 0)
        .scaleEffect(isRevealed ? 1 : 0.95)
        .offset(y: isRevealed ? 0 : 10)
        .animation(SmoothRevealAnimation.motion.delay(revealDelay), value: isRevealed)
    }
}

struct TimelinePurchaseInsightRow: View {
    let why: String
    let revealDelay: Double
    var isRevealed: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.violetStateForeground)
                .frame(width: 28, height: 28)
                .background(Color.violetStateBackground)
                .clipShape(Circle())

            PurchaseInsightWhyText(why: why)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .opacity(isRevealed ? 1 : 0)
        .offset(y: isRevealed ? 0 : 8)
        .animation(SmoothRevealAnimation.motion.delay(revealDelay), value: isRevealed)
    }
}

private struct PurchaseInsightWhyText: View {
    let why: String

    var body: some View {
        FlowLayout(spacing: 0) {
            ForEach(Array(PurchaseInsightWhyParser.tokens(from: why).enumerated()), id: \.offset) { _, token in
                switch token {
                case .text(let value):
                    Text(value)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .date(let value):
                    Text(value)
                        .font(.caption2.weight(.semibold).monospaced())
                        .foregroundStyle(Color.violetStateForeground)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.violetStateBackground)
                        .clipShape(Capsule())
                        .padding(.horizontal, 2)
                }
            }
        }
    }
}

private enum PurchaseInsightToken {
    case text(String)
    case date(String)
}

private enum PurchaseInsightWhyParser {
    private static let datePattern = /\d{2}\/\d{2}\/\d{4}/

    static func tokens(from why: String) -> [PurchaseInsightToken] {
        var tokens: [PurchaseInsightToken] = []
        var remaining = why[...]

        while !remaining.isEmpty {
            if let match = remaining.firstMatch(of: datePattern) {
                tokens += textTokens(from: String(remaining[..<match.range.lowerBound]))
                tokens.append(.date(String(match.output)))
                remaining = remaining[match.range.upperBound...]
            } else {
                tokens += textTokens(from: String(remaining))
                break
            }
        }

        return tokens
    }

    private static func textTokens(from text: String) -> [PurchaseInsightToken] {
        guard !text.isEmpty else { return [] }

        var tokens: [PurchaseInsightToken] = []
        var current = ""

        for character in text {
            if character.isWhitespace {
                if !current.isEmpty {
                    tokens.append(.text(current))
                    current = ""
                }
                tokens.append(.text(String(character)))
            } else {
                current.append(character)
            }
        }

        if !current.isEmpty {
            tokens.append(.text(current))
        }

        return tokens
    }
}

#Preview {
    VStack(spacing: 12) {
        TimelineFeaturedCard(
            card: APICard(
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
            ),
            status: APICardStatus(
                status: "due_soon",
                cycleStart: .now,
                cycleEnd: .now,
                paymentDueDate: .now,
                daysUntilPayment: 28,
                daysOverdue: 0,
                optimalPurchaseDay: 16,
                isOptimalPurchaseDay: false,
                isPaidThisCycle: false
            ),
            revealDelay: 0,
            isRevealed: true
        )

        TimelinePurchaseInsightRow(
            why: "CMR •••• 1234 te da 48 días de financiamiento: una compra hoy vence el 05/08/2026.",
            revealDelay: 0.08,
            isRevealed: true
        )
    }
    .padding()
}
