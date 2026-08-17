import SwiftUI

extension View {
    /// The grouped container used for content blocks sitting on `appBackground`.
    ///
    /// The default radius matches `SwipeActionRow`'s clip, so rows keep their
    /// shape while the swipe drawer is open.
    func sectionCard(cornerRadius: CGFloat = 14) -> some View {
        background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.defaultBorder, lineWidth: 1)
            }
    }
}
