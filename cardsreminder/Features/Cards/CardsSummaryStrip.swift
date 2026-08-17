import SwiftUI

/// Horizontal status chips that double as filters for the card list.
struct CardsSummaryStrip: View {
    let counts: [CardPaymentStatusKind: Int]
    let totalCount: Int
    @Binding var selection: CardsStatusFilter

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var availableKinds: [CardPaymentStatusKind] {
        CardsListArrangement.urgencyOrder.filter { (counts[$0] ?? 0) > 0 }
    }

    var body: some View {
        if availableKinds.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(
                        title: String(format: String(localized: "cards_filter_all"), totalCount),
                        foreground: .primary,
                        background: Color(.secondarySystemBackground),
                        filter: .all
                    )

                    ForEach(availableKinds, id: \.self) { kind in
                        chip(
                            title: label(for: kind, count: counts[kind] ?? 0),
                            foreground: kind.foregroundColor,
                            background: kind.backgroundColor,
                            filter: .kind(kind)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private func chip(
        title: String,
        foreground: Color,
        background: Color,
        filter: CardsStatusFilter
    ) -> some View {
        let isSelected = selection == filter

        return Button {
            Haptics.selection()
            withAnimation(SmoothRevealAnimation.motion(reduceMotion: reduceMotion)) {
                selection = isSelected ? .all : filter
            }
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(foreground)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(background.opacity(isSelected ? 1 : 0.5))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(foreground.opacity(isSelected ? 0.55 : 0), lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func label(for kind: CardPaymentStatusKind, count: Int) -> String {
        String(format: String(localized: kind.countFormatKey), count)
    }
}

private struct CardsSummaryStripPreview: View {
    @State private var selection: CardsStatusFilter = .all

    var body: some View {
        CardsSummaryStrip(
            counts: [.overdue: 1, .urgent: 2, .dueSoon: 1, .paid: 3],
            totalCount: 7,
            selection: $selection
        )
    }
}

#Preview {
    CardsSummaryStripPreview()
}
