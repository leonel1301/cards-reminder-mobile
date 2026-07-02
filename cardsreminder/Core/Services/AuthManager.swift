import AuthenticationServices
import CryptoKit
import FirebaseAnalytics
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

@Observable
@MainActor
final class AuthManager {
    var user: User?
    var isLoading = false
    var errorMessage: String?

    var isSignedIn: Bool { user != nil }

    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var appleSignInCoordinator: AppleSignInCoordinator?

    init() {
        user = Auth.auth().currentUser
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
                Analytics.setUserID(user?.uid)
            }
        }
    }

    func signInWithGoogle() async {
        guard let rootViewController = Self.topViewController() else {
            errorMessage = String(localized: "error_sign_in_screen")
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            guard let idToken = result.user.idToken?.tokenString else {
                throw AuthError.missingGoogleToken
            }

            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            user = authResult.user
        } catch {
            if (error as NSError).code != GIDSignInError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }

    func signInWithApple() {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        let coordinator = AppleSignInCoordinator()
        appleSignInCoordinator = coordinator

        coordinator.signIn { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                defer {
                    self.appleSignInCoordinator = nil
                    self.isLoading = false
                }

                switch result {
                case .success(let (appleIDCredential, nonce)):
                    await self.completeAppleSignIn(credential: appleIDCredential, nonce: nonce)

                case .failure(let error):
                    if !Self.isBenignAppleSignInError(error) {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }

    private func completeAppleSignIn(
        credential appleIDCredential: ASAuthorizationAppleIDCredential,
        nonce: String
    ) async {
        guard let identityToken = appleIDCredential.identityToken,
              let idTokenString = String(data: identityToken, encoding: .utf8) else {
            errorMessage = String(localized: "error_apple_credential")
            return
        }

        do {
            let credential = OAuthProvider.appleCredential(
                withIDToken: idTokenString,
                rawNonce: nonce,
                fullName: appleIDCredential.fullName
            )
            let authResult = try await Auth.auth().signIn(with: credential)
            user = authResult.user
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private static func isBenignAppleSignInError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == ASAuthorizationError.errorDomain else { return false }

        return nsError.code == ASAuthorizationError.canceled.rawValue
            || nsError.code == ASAuthorizationError.unknown.rawValue
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            user = nil
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("No se pudo generar un nonce seguro. Código: \(errorCode)")
        }

        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(randomBytes.map { charset[Int($0) % charset.count] })
    }

    static func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        return hashedData.compactMap { String(format: "%02x", $0) }.joined()
    }

    @MainActor
    static func keyWindow() -> UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    @MainActor
    static func topViewController() -> UIViewController? {
        _topViewController(base: keyWindow()?.rootViewController)
    }

    private static func _topViewController(base: UIViewController?) -> UIViewController? {
        if let navigationController = base as? UINavigationController {
            return _topViewController(base: navigationController.visibleViewController)
        }
        if let tabBarController = base as? UITabBarController {
            return _topViewController(base: tabBarController.selectedViewController)
        }
        if let presented = base?.presentedViewController {
            return _topViewController(base: presented)
        }
        return base
    }
    
}

private enum AuthError: LocalizedError {
    case missingGoogleToken

    var errorDescription: String? {
        switch self {
        case .missingGoogleToken:
            return String(localized: "error_google_token")
        }
    }
}
