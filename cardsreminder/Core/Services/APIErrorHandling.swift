import SwiftUI

@Observable
@MainActor
final class APIAlertCenter {
    static let shared = APIAlertCenter()

    var message: String?

    func present(message: String) {
        self.message = message
    }

    func dismiss() {
        message = nil
    }
}

@MainActor
enum APIErrorHandling {
    static func handle(_ error: Error, setMessage: (String) -> Void) {
        guard !error.isCancelled else { return }

        let message = userFacingMessage(from: error)

        if shouldPresentAlert(for: error) {
            APIAlertCenter.shared.present(message: message)
        } else {
            setMessage(message)
        }
    }

    static func userFacingMessage(from error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.isEmpty {
            return description
        }
        return error.localizedDescription
    }

    static func shouldPresentAlert(for error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        if case .serverError(let statusCode, _) = apiError {
            return (400...499).contains(statusCode)
        }
        return false
    }
}

extension View {
    func apiErrorAlert() -> some View {
        modifier(APIErrorAlertModifier())
    }
}

private struct APIErrorAlertModifier: ViewModifier {
    @Bindable private var alertCenter = APIAlertCenter.shared

    func body(content: Content) -> some View {
        content.alert(
            Text(alertCenter.message ?? ""),
            isPresented: Binding(
                get: { alertCenter.message != nil },
                set: { if !$0 { alertCenter.dismiss() } }
            )
        ) {
            Button("action_continue", role: .cancel) {
                alertCenter.dismiss()
            }
        }
    }
}

private extension Error {
    var isCancelled: Bool {
        if self is CancellationError { return true }
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
