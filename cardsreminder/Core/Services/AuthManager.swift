import AuthenticationServices
import CryptoKit
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

    init() {
        user = Auth.auth().currentUser
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.user = user
            }
        }
    }

    func signInWithGoogle() async {
        guard let rootViewController = Self.topViewController() else {
            errorMessage = "No se pudo abrir la pantalla de inicio de sesión."
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

    func handleAppleSignIn(result: Result<ASAuthorization, Error>, nonce: String?) async {
        isLoading = true
        errorMessage = nil

        switch result {
        case .success(let authorization):
            guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let identityToken = appleIDCredential.identityToken,
                  let idTokenString = String(data: identityToken, encoding: .utf8),
                  let nonce else {
                errorMessage = "No se pudo obtener la credencial de Apple."
                isLoading = false
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

        case .failure(let error):
            if (error as NSError).code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
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
    static func topViewController() -> UIViewController? {
        let base = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
        return _topViewController(base: base)
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
            return "No se pudo obtener el token de Google."
        }
    }
}
