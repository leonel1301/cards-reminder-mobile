import SwiftUI
import UIKit

struct CreditCardView: View {
    let card: APICard
    var onEdit: (() -> Void)?
    var onDelete: (() -> Void)?

    private var contentColor: Color {
        card.color.isLightForegroundPreferred ? Color.black.opacity(0.82) : .white
    }

    private var secondaryContentColor: Color {
        card.color.isLightForegroundPreferred ? Color.black.opacity(0.55) : .white.opacity(0.78)
    }

    var body: some View {
        Button {
            onEdit?()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let onEdit {
                Button(action: onEdit) {
                    Label("screen_edit_card_title", systemImage: "pencil")
                }
            }

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Label("action_delete_card", systemImage: "trash")
                }
            }
        }
    }

    private var cardContent: some View {
        ZStack(alignment: .topTrailing) {
            cardBackground

            VStack(alignment: .leading, spacing: 0) {
                headerRow

                Spacer(minLength: 12)

                cardNumber

                Spacer(minLength: 12)

                footerRow
            }
            .padding(20)
            .foregroundStyle(contentColor)

            if !card.isActive {
                inactiveBadge
            }
        }
        .aspectRatio(1.586, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: card.color.opacity(card.isActive ? 0.35 : 0.15), radius: 10, y: 6)
        .opacity(card.isActive ? 1 : 0.72)
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(card.color)

            RoundedRectangle(cornerRadius: 16, style: .continuous)
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
    }

    private var headerRow: some View {
        HStack(alignment: .top) {
            chipView

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(card.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)

                if let issuer = card.issuer, !issuer.isEmpty {
                    Text(issuer)
                        .font(.caption)
                        .foregroundStyle(secondaryContentColor)
                }
            }
        }
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
            .frame(width: 38, height: 28)
            .overlay {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(.black.opacity(0.12), lineWidth: 0.5)
            }
    }

    private var cardNumber: some View {
        Text(formattedCardNumber)
            .font(.system(.title3, design: .monospaced).weight(.medium))
            .tracking(2)
            .minimumScaleFactor(0.8)
            .lineLimit(1)
    }

    private var footerRow: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("card_billing_label")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(secondaryContentColor)

                Text(
                    String(
                        format: String(localized: "billing_cut_payment"),
                        card.billingCycleDay,
                        card.paymentDueDay
                    )
                )
                    .font(.caption.weight(.medium))
            }

            Spacer()
        }
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

    private var formattedCardNumber: String {
        "•••• •••• •••• \(card.lastFourDigits)"
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
    VStack(spacing: 16) {
        CreditCardView(card: APICard(
            id: UUID(),
            userID: UUID(),
            ownerID: UUID(),
            name: "Visa Banco X",
            lastFourDigits: "4532",
            issuer: "Banco X",
            billingCycleDay: 15,
            paymentDueDay: 5,
            colorHex: "6366F1",
            notes: nil,
            isActive: true,
            createdAt: .now,
            updatedAt: .now
        ))

        CreditCardView(card: APICard(
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
        ))
    }
    .padding()
}
