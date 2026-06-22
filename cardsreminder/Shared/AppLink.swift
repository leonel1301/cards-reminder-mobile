import SafariServices
import SwiftUI

struct PresentedURL: Identifiable, Equatable {
    let url: URL

    var id: String { url.absoluteString }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

enum AppLink {
    static let lenaraHomepage = URL(string: "https://lenaralabs.com/")!

    static func shouldOpenExternally(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        let isLenaraHost = host == "lenaralabs.com" || host == "www.lenaralabs.com"
        let isHomepage = url.path.isEmpty || url.path == "/"
        return isLenaraHost && isHomepage
    }

    @MainActor
    static func open(
        _ url: URL,
        presentingIn presentedURL: Binding<PresentedURL?>,
        openURL: OpenURLAction
    ) {
        if shouldOpenExternally(url) {
            _ = openURL(url)
        } else {
            presentedURL.wrappedValue = PresentedURL(url: url)
        }
    }
}

extension View {
    func inAppSafariSheet(presentedURL: Binding<PresentedURL?>) -> some View {
        sheet(item: presentedURL) { item in
            SafariView(url: item.url)
                .ignoresSafeArea()
        }
    }
}
