import SwiftUI

struct CardWalletEntry: Identifiable, Equatable {
    let card: APICard
    let status: APICardStatus?

    var id: UUID { card.id }
}

/// Wallet-style deck: every card but the open one collapses to a peeking header strip,
/// and the open card reveals its actions underneath.
struct CardWalletStack: View {
    let entries: [CardWalletEntry]
    var ownerName: (UUID) -> String? = { _ in nil }
    var busyCardID: UUID?
    @Binding var openCardID: UUID?

    var onOpenPayments: (APICard) -> Void
    var onMarkPaid: (APICard) -> Void
    var onEdit: (APICard) -> Void
    var onDelete: (APICard) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .subheadline) private var peekHeight: CGFloat = 82

    private static let cardSpacing: CGFloat = 16

    /// Overlapping cards only pay off with a few of them, and they get in the way of
    /// VoiceOver and of the taller layouts that accessibility text sizes produce.
    private var usesDeckLayout: Bool {
        entries.count > 2 && !voiceOverEnabled && !dynamicTypeSize.isAccessibilitySize
    }

    private var resolvedOpenID: UUID? {
        if let openCardID, entries.contains(where: { $0.id == openCardID }) {
            return openCardID
        }
        return entries.first?.id
    }

    private var openIndex: Int? {
        guard let resolvedOpenID else { return nil }
        return entries.firstIndex { $0.id == resolvedOpenID }
    }

    var body: some View {
        Group {
            if usesDeckLayout {
                WalletDeckLayout(
                    peekHeight: peekHeight,
                    openIndex: openIndex,
                    spacing: Self.cardSpacing
                ) {
                    ForEach(entries) { entry in
                        slot(for: entry)
                    }
                }
            } else {
                VStack(spacing: Self.cardSpacing) {
                    ForEach(entries) { entry in
                        slot(for: entry)
                    }
                }
            }
        }
        .animation(motion, value: resolvedOpenID)
        .animation(motion, value: entries)
    }

    private var motion: Animation? {
        SmoothRevealAnimation.motion(reduceMotion: reduceMotion)
    }

    private func slot(for entry: CardWalletEntry) -> some View {
        let isOpen = entry.id == resolvedOpenID

        return VStack(spacing: 10) {
            CreditCardView(
                card: entry.card,
                status: entry.status,
                ownerName: ownerName(entry.card.ownerID),
                isElevated: isOpen && usesDeckLayout,
                onMarkPaid: entry.card.isActive ? { onMarkPaid(entry.card) } : nil
            )
            .overlay {
                if busyCardID == entry.id {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay { ProgressView() }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .onTapGesture { handleTap(on: entry, isOpen: isOpen) }
            .contextMenu { menu(for: entry) }

            if isOpen {
                actionRow(for: entry)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(entry.card.name))
        .accessibilityAction(named: Text("payments_view_history")) { onOpenPayments(entry.card) }
        .accessibilityAction(named: Text("screen_edit_card_title")) { onEdit(entry.card) }
        .accessibilityAction(named: Text("action_delete_card")) { onDelete(entry.card) }
    }

    private func handleTap(on entry: CardWalletEntry, isOpen: Bool) {
        guard !isOpen else {
            Haptics.lightImpact()
            onOpenPayments(entry.card)
            return
        }

        Haptics.selection()
        withAnimation(motion) {
            openCardID = entry.id
        }
    }

    @ViewBuilder
    private func menu(for entry: CardWalletEntry) -> some View {
        Button {
            onOpenPayments(entry.card)
        } label: {
            Label("payments_view_history", systemImage: "clock.arrow.circlepath")
        }

        if entry.card.isActive, entry.status?.isPaidThisCycle != true {
            Button {
                onMarkPaid(entry.card)
            } label: {
                Label("action_pay", systemImage: "checkmark.seal.fill")
            }
        }

        Button {
            onEdit(entry.card)
        } label: {
            Label("screen_edit_card_title", systemImage: "pencil")
        }

        Button(role: .destructive) {
            onDelete(entry.card)
        } label: {
            Label("action_delete_card", systemImage: "trash")
        }
    }

    private func actionRow(for entry: CardWalletEntry) -> some View {
        HStack(spacing: 8) {
            if entry.card.isActive, entry.status?.isPaidThisCycle != true {
                actionButton("action_pay", systemImage: "checkmark.seal.fill", isProminent: true) {
                    onMarkPaid(entry.card)
                }
            }

            actionButton("cards_action_history", systemImage: "clock.arrow.circlepath") {
                onOpenPayments(entry.card)
            }

            actionButton("cards_action_edit", systemImage: "pencil") {
                onEdit(entry.card)
            }

            actionButton("cards_action_delete", systemImage: "trash", isDestructive: true) {
                onDelete(entry.card)
            }
        }
    }

    private func actionButton(
        _ titleKey: LocalizedStringKey,
        systemImage: String,
        isProminent: Bool = false,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.subheadline)

                Text(titleKey)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .foregroundStyle(foreground(isProminent: isProminent, isDestructive: isDestructive))
            .background(background(isProminent: isProminent))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                if !isProminent {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.defaultBorder, lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func foreground(isProminent: Bool, isDestructive: Bool) -> Color {
        if isProminent { return Color.emeraldStateForeground }
        if isDestructive { return Color.redStateForeground }
        return .primary
    }

    private func background(isProminent: Bool) -> Color {
        isProminent ? Color.emeraldStateBackground : Color(.secondarySystemBackground)
    }
}

/// Stacks the cards vertically so that collapsed ones only expose `peekHeight`,
/// while the open one is laid out at its full height followed by a gap.
private struct WalletDeckLayout: Layout {
    var peekHeight: CGFloat
    var openIndex: Int?
    var spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let heights = heights(of: subviews, width: width)
        guard !heights.isEmpty else { return CGSize(width: width, height: 0) }

        let offsets = offsets(for: heights)
        let bottom = zip(offsets, heights).map(+).max() ?? 0
        return CGSize(width: width, height: bottom)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let heights = heights(of: subviews, width: bounds.width)
        let offsets = offsets(for: heights)

        for index in subviews.indices {
            subviews[index].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + offsets[index]),
                proposal: ProposedViewSize(width: bounds.width, height: heights[index])
            )
        }
    }

    private func heights(of subviews: Subviews, width: CGFloat) -> [CGFloat] {
        subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
    }

    private func offsets(for heights: [CGFloat]) -> [CGFloat] {
        var offsets: [CGFloat] = []
        offsets.reserveCapacity(heights.count)

        var cursor: CGFloat = 0
        for (index, height) in heights.enumerated() {
            offsets.append(cursor)
            cursor += index == openIndex ? height + spacing : peekHeight
        }

        return offsets
    }
}

private struct CardWalletStackPreview: View {
    @State private var openCardID: UUID?

    private let entries: [CardWalletEntry] = ["Visa Banco X", "Falabella", "Amex Platinum", "Mastercard Oro"]
        .enumerated()
        .map { index, name in
            CardWalletEntry(
                card: APICard(
                    id: UUID(),
                    userID: UUID(),
                    ownerID: UUID(),
                    name: name,
                    lastFourDigits: "45\(index)2",
                    issuer: "Banco",
                    billingCycleDay: 15,
                    paymentDueDay: 5,
                    colorHex: ["6366F1", "22C55E", "0F172A", "F59E0B"][index],
                    notes: nil,
                    isActive: true,
                    createdAt: .now,
                    updatedAt: .now
                ),
                status: APICardStatus(
                    status: ["overdue", "urgent", "due_soon", "on_track"][index],
                    cycleStart: .now.addingTimeInterval(-14 * 86_400),
                    cycleEnd: .now.addingTimeInterval(-2 * 86_400),
                    paymentDueDate: .now.addingTimeInterval(Double(index) * 86_400),
                    daysUntilPayment: index,
                    daysOverdue: index == 0 ? 3 : 0,
                    optimalPurchaseDay: 16,
                    isOptimalPurchaseDay: false,
                    isPaidThisCycle: false
                )
            )
        }

    var body: some View {
        ScrollView {
            CardWalletStack(
                entries: entries,
                openCardID: $openCardID,
                onOpenPayments: { _ in },
                onMarkPaid: { _ in },
                onEdit: { _ in },
                onDelete: { _ in }
            )
            .padding(16)
        }
        .background(Color.appBackground)
    }
}

#Preview {
    CardWalletStackPreview()
}
