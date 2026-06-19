import AuthenticationServices
import UIKit

final class AppleSignInCoordinator: NSObject {
    typealias Completion = (Result<(ASAuthorizationAppleIDCredential, String), Error>) -> Void

    private var currentNonce: String?
    private var onComplete: Completion?

    func signIn(onComplete: @escaping Completion) {
        self.onComplete = onComplete

        let nonce = AuthManager.randomNonceString()
        currentNonce = nonce

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = AuthManager.sha256(nonce)

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    private func finish(with result: Result<(ASAuthorizationAppleIDCredential, String), Error>) {
        onComplete?(result)
        currentNonce = nil
        onComplete = nil
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerDelegate {
    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let nonce = currentNonce else {
            finish(with: .failure(AppleSignInError.missingCredential))
            return
        }

        finish(with: .success((credential, nonce)))
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        finish(with: .failure(error))
    }
}

extension AppleSignInCoordinator: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let window = Self.keyWindow else {
            fatalError("No se encontró una ventana activa para Sign in with Apple.")
        }
        return window
    }

    private static var keyWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}

enum AppleSignInError: LocalizedError {
    case missingCredential

    var errorDescription: String? {
        switch self {
        case .missingCredential:
            return String(localized: "error_apple_credential")
        }
    }
}
