import SwiftUI

struct PoweredByLenaraFooter: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("footer_powered_by")
                .foregroundStyle(Color.secondaryText)

            Text("Lenara")
                .fontWeight(.semibold)
                .foregroundStyle(Color.primaryAction)
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("footer_powered_by_lenara"))
    }
}

#Preview {
    PoweredByLenaraFooter()
        .padding()
        .background(Color.appBackground)
}
