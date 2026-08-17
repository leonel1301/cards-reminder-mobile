import SwiftUI

/// Trailing swipe action for rows that live outside a `List`, where
/// `.swipeActions` is not available.
///
/// Opening is exclusive: the parent owns `openID`, so revealing one row closes
/// any other. Swiping never fires the action on its own; it reveals a button the
/// user still has to tap.
struct SwipeActionRow<Content: View>: View {
    private static var actionWidth: CGFloat { 92 }
    /// How far past the resting position the drawer can be dragged.
    private static var overshoot: CGFloat { 16 }

    let id: String
    let titleKey: LocalizedStringKey
    let systemImage: String
    let tint: Color
    let isEnabled: Bool
    @Binding var openID: String?
    let action: () -> Void
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragTranslation: CGFloat = 0

    init(
        id: String,
        titleKey: LocalizedStringKey,
        systemImage: String,
        tint: Color,
        isEnabled: Bool = true,
        openID: Binding<String?>,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.id = id
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.tint = tint
        self.isEnabled = isEnabled
        self._openID = openID
        self.action = action
        self.content = content()
    }

    var body: some View {
        if isEnabled {
            drawer
        } else {
            content
        }
    }

    private var isOpen: Bool {
        openID == id
    }

    private var offset: CGFloat {
        let resting = isOpen ? -Self.actionWidth : 0
        return min(0, max(-Self.actionWidth - Self.overshoot, resting + dragTranslation))
    }

    private var motion: Animation? {
        reduceMotion ? nil : .snappy(duration: 0.25)
    }

    private var drawer: some View {
        ZStack(alignment: .trailing) {
            // Only present while visible, so its tint cannot peek through the
            // content's rounded corners at rest.
            if offset < -1 {
                actionButton
            }

            content
                .offset(x: offset)
                .overlay {
                    if isOpen {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { setOpen(false) }
                    }
                }
                .simultaneousGesture(dragGesture)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var actionButton: some View {
        Button {
            setOpen(false)
            action()
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))

                Text(titleKey)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .frame(width: Self.actionWidth)
            .frame(maxHeight: .infinity)
            .background(tint)
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 18, coordinateSpace: .local)
            .onChanged { value in
                // Let the scroll view keep vertical drags.
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                dragTranslation = value.translation.width
            }
            .onEnded { value in
                let settled = (isOpen ? -Self.actionWidth : 0) + value.translation.width
                let shouldOpen = settled < -Self.actionWidth / 2

                if shouldOpen != isOpen {
                    Haptics.selection()
                }

                withAnimation(motion) {
                    dragTranslation = 0
                    openID = shouldOpen ? id : nil
                }
            }
    }

    private func setOpen(_ open: Bool) {
        withAnimation(motion) {
            dragTranslation = 0
            openID = open ? id : nil
        }
    }
}

private struct SwipeActionRowPreview: View {
    @State private var openID: String?

    var body: some View {
        VStack(spacing: 12) {
            ForEach(["a", "b"], id: \.self) { id in
                SwipeActionRow(
                    id: id,
                    titleKey: "payments_pay_action",
                    systemImage: "checkmark.circle.fill",
                    tint: Color.emeraldStateForeground,
                    openID: $openID,
                    action: {}
                ) {
                    Text(verbatim: "Row \(id)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.secondarySystemBackground))
                }
            }
        }
        .padding()
    }
}

#Preview {
    SwipeActionRowPreview()
}
