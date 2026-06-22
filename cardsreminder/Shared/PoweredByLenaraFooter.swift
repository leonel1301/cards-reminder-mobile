import SwiftUI

struct PoweredByLenaraFooter: View {
    @Environment(\.openURL) private var openURL

    private let lenaraURL = URL(string: "https://lenaralabs.com/")!

    var body: some View {
        Button {
            openURL(lenaraURL)
        } label: {
            HStack(spacing: 4) {
                Text("footer_powered_by")
                    .foregroundStyle(.secondary)

                Text("Lenara")
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.accentColor)

                Image(systemName: "arrow.up.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .font(.caption)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("footer_powered_by_lenara"))
    }
}

#Preview {
    PoweredByLenaraFooter()
        .padding()
        .background(Color.appBackground)
}
