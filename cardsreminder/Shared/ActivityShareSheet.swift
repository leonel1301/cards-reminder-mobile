import SwiftUI
import UIKit

struct ActivitySharePayload: Identifiable {
    let id = UUID()
    let items: [Any]
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

extension View {
    func activityShareSheet(payload: Binding<ActivitySharePayload?>) -> some View {
        sheet(item: payload) { value in
            ActivityShareSheet(items: value.items)
        }
    }
}
