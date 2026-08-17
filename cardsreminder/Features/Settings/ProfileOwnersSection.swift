import SwiftUI

struct ProfileOwnersSection: View {
    let owners: [APIOwner]
    let isLoading: Bool
    let contentRevision: Int
    /// `nil` while cards are still loading, so the row hides the chip instead of
    /// claiming the owner has none.
    let cardCount: (APIOwner) -> Int?
    @Binding var openSwipeOwnerID: String?
    let onAdd: () -> Void
    let onEdit: (APIOwner) -> Void
    let onDelete: (APIOwner) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if isLoading && owners.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if owners.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(owners.enumerated()), id: \.element.id) { index, owner in
                        row(owner)
                            .transition(SmoothRevealAnimation.transition(reduceMotion: reduceMotion))
                            .animation(
                                staggeredMotion(for: index),
                                value: contentRevision
                            )
                    }
                }
            }
        }
    }

    private func staggeredMotion(for index: Int) -> Animation? {
        SmoothRevealAnimation
            .motion(reduceMotion: reduceMotion)?
            .delay(SmoothRevealAnimation.staggerDelay(for: index))
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("owners_section")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if !owners.isEmpty {
                Text("\(owners.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }

            Spacer(minLength: 0)

            if !owners.isEmpty {
                Button {
                    Haptics.lightImpact()
                    onAdd()
                } label: {
                    Image(systemName: "plus")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primaryAction)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("action_add_owner"))
            }
        }
        .frame(minHeight: 44)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("owners_empty_message")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Haptics.lightImpact()
                onAdd()
            } label: {
                Label("action_add_owner", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primaryAction)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .sectionCard()
    }

    private func row(_ owner: APIOwner) -> some View {
        SwipeActionRow(
            id: owner.id.uuidString,
            titleKey: "action_delete",
            systemImage: "trash.fill",
            tint: Color.redStateForeground,
            isEnabled: !owner.isSelf,
            openID: $openSwipeOwnerID,
            action: { onDelete(owner) }
        ) {
            Button {
                Haptics.lightImpact()
                onEdit(owner)
            } label: {
                rowContent(owner)
            }
            .buttonStyle(.plain)
        }
        .contextMenu {
            Button {
                onEdit(owner)
            } label: {
                Label("action_edit", systemImage: "pencil")
            }

            if !owner.isSelf {
                Button(role: .destructive) {
                    onDelete(owner)
                } label: {
                    Label("action_delete_owner", systemImage: "trash")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("profile_owner_edit_hint"))
        .accessibilityAction {
            onEdit(owner)
        }
        .accessibilityActions {
            if !owner.isSelf {
                Button("action_delete_owner") { onDelete(owner) }
            }
        }
    }

    private func rowContent(_ owner: APIOwner) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(owner.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if owner.isSelf {
                        Text("owner_self_badge")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.primaryAction.opacity(0.15), in: Capsule())
                    }
                }

                Text(owner.salaryDayLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            if let count = cardCount(owner) {
                Text(String(format: String(localized: "profile_owner_cards_count"), count))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .sectionCard()
    }
}

private struct ProfileOwnersSectionPreview: View {
    @State private var openSwipeOwnerID: String?

    private let owners: [APIOwner] = [
        APIOwner(
            id: UUID(),
            userID: UUID(),
            name: "Leonel",
            salaryDay: 15,
            isSelf: true,
            createdAt: .now,
            updatedAt: .now
        ),
        APIOwner(
            id: UUID(),
            userID: UUID(),
            name: "Ana",
            salaryDay: nil,
            isSelf: false,
            createdAt: .now,
            updatedAt: .now
        )
    ]

    var body: some View {
        ScrollView {
            ProfileOwnersSection(
                owners: owners,
                isLoading: false,
                contentRevision: 0,
                cardCount: { $0.isSelf ? 3 : 1 },
                openSwipeOwnerID: $openSwipeOwnerID,
                onAdd: {},
                onEdit: { _ in },
                onDelete: { _ in }
            )
            .padding(16)
        }
        .background(Color.appBackground)
    }
}

#Preview {
    ProfileOwnersSectionPreview()
}
