import SwiftUI

/// Card chips that narrow the grid down to a single card, which also keeps the
/// day cells readable once there are more cards than bar slots.
struct CalendarCardFilterRow: View {
    let cards: [APICard]
    @Binding var selectedCardID: UUID?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                allCardsChip

                ForEach(cards) { card in
                    cardChip(card)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private var allCardsChip: some View {
        chip(
            isSelected: selectedCardID == nil,
            tint: .primary,
            action: { select(nil) }
        ) {
            Text("calendar_filter_all_cards")
                .font(.caption.weight(.medium))
        }
    }

    private func cardChip(_ card: APICard) -> some View {
        chip(
            isSelected: selectedCardID == card.id,
            tint: card.color,
            action: { select(card.id) }
        ) {
            HStack(spacing: 5) {
                Circle()
                    .fill(card.color)
                    .frame(width: 8, height: 8)

                Text(card.name)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
            }
        }
    }

    private func chip<Label: View>(
        isSelected: Bool,
        tint: Color,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) -> some View {
        Button(action: action) {
            label()
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .foregroundStyle(isSelected ? tint : .primary)
                .background(isSelected ? tint.opacity(0.18) : Color(.tertiarySystemFill))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? tint.opacity(0.55) : .clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func select(_ cardID: UUID?) {
        Haptics.selection()
        withAnimation(SmoothRevealAnimation.motion(reduceMotion: reduceMotion)) {
            selectedCardID = selectedCardID == cardID ? nil : cardID
        }
    }
}

private struct CalendarCardFilterRowPreview: View {
    @State private var selectedCardID: UUID?

    private let cards: [APICard] = ["Visa Banco X", "Falabella", "Amex"].enumerated().map { index, name in
        APICard(
            id: UUID(),
            userID: UUID(),
            ownerID: UUID(),
            name: name,
            lastFourDigits: "000\(index)",
            issuer: nil,
            billingCycleDay: 15,
            paymentDueDay: 5,
            colorHex: ["6366F1", "22C55E", "F59E0B"][index],
            notes: nil,
            isActive: true,
            createdAt: .now,
            updatedAt: .now
        )
    }

    var body: some View {
        CalendarCardFilterRow(cards: cards, selectedCardID: $selectedCardID)
    }
}

#Preview {
    CalendarCardFilterRowPreview()
}
