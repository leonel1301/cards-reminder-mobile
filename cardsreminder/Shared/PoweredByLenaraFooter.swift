import SwiftUI

struct PoweredByLenaraFooter: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Powered by")
                .foregroundStyle(Color.secondaryText)

            Text("Lenara")
                .fontWeight(.semibold)
                .foregroundStyle(Color.primaryAction)
        }
        .font(.caption)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Powered by Lenara")
    }
}

#Preview {
    PoweredByLenaraFooter()
        .padding()
        .background(Color.appBackground)
}
