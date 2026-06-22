import FirebaseAuth
import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class UserAPIService {
    private struct CachedUserSession: Codable {
        let user: APIUser
        let requiredTermsVersion: String
        let userID: String
    }

    var isLoading = false
    var errorMessage: String?

    private(set) var currentUser: APIUser?
    private(set) var requiredTermsVersion: String?
    private(set) var loadedUserID: String?
    private(set) var hasResolvedTermsStatus = false
    private(set) var contentRevision = 0

    private let api = APIService.shared
    private var fetchTask: Task<Void, Never>?
    private static let sessionCacheKey = "cachedUserSession"

    var hasLoaded: Bool {
        guard let loadedUserID, loadedUserID == Auth.auth().currentUser?.uid else {
            return false
        }
        return true
    }

    var needsTermsAcceptance: Bool {
        guard let requiredTermsVersion, let currentUser else { return false }
        return !currentUser.hasAcceptedTerms(requiredVersion: requiredTermsVersion)
    }

    func resetSession() {
        fetchTask?.cancel()
        fetchTask = nil
        currentUser = nil
        requiredTermsVersion = nil
        loadedUserID = nil
        hasResolvedTermsStatus = false
        contentRevision = 0
        errorMessage = nil
        isLoading = false
        Self.clearCachedSession()
    }

    func refreshCurrentUser(into context: ModelContext? = nil) async {
        guard let userID = Auth.auth().currentUser?.uid else {
            resetSession()
            return
        }

        if let fetchTask {
            await fetchTask.value
            syncProfile(currentUser, into: context)
            return
        }

        let task = Task { @MainActor in
            isLoading = true
            errorMessage = nil

            do {
                async let terms = api.publicRequest(path: "/terms") as APITerms
                async let user = api.request(path: "/me") as APIUser
                let (termsInfo, profile) = try await (terms, user)
                applySession(
                    user: profile,
                    requiredVersion: termsInfo.termsVersion,
                    for: userID,
                    into: context
                )
            } catch {
                APIErrorHandling.handle(error) { errorMessage = $0 }
                if let cached = Self.loadCachedSession(for: userID) {
                    applySession(
                        user: cached.user,
                        requiredVersion: cached.requiredTermsVersion,
                        for: userID,
                        into: context
                    )
                } else {
                    hasResolvedTermsStatus = true
                }
            }

            isLoading = false
            fetchTask = nil
        }

        fetchTask = task
        await task.value
    }

    func fetchProfile(into context: ModelContext) async {
        if hasLoaded, let currentUser {
            syncProfile(currentUser, into: context)
            return
        }
        await refreshCurrentUser(into: context)
    }

    func acceptTerms(into context: ModelContext? = nil) async -> Bool {
        guard let userID = Auth.auth().currentUser?.uid else {
            resetSession()
            return false
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let user: APIUser = try await api.request(path: "/me/accept-terms", method: "PATCH")

            if requiredTermsVersion == nil {
                let terms: APITerms = try await api.publicRequest(path: "/terms")
                requiredTermsVersion = terms.termsVersion
            }

            applySession(
                user: user,
                requiredVersion: requiredTermsVersion!,
                for: userID,
                into: context
            )
            return !needsTermsAcceptance
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return false
        }
    }

    func deleteAccount() async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await api.requestVoid(path: "/me", method: "DELETE")
            resetSession()
            return true
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return false
        }
    }

    private func applySession(
        user: APIUser,
        requiredVersion: String,
        for userID: String,
        into context: ModelContext?
    ) {
        Self.saveCachedSession(
            CachedUserSession(
                user: user,
                requiredTermsVersion: requiredVersion,
                userID: userID
            )
        )

        withAnimation(SmoothRevealAnimation.motion) {
            currentUser = user
            requiredTermsVersion = requiredVersion
            loadedUserID = userID
            hasResolvedTermsStatus = true
            contentRevision += 1

            syncProfile(user, into: context)
        }
    }

    private static func saveCachedSession(_ session: CachedUserSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        UserDefaults.standard.set(data, forKey: sessionCacheKey)
    }

    private static func loadCachedSession(for userID: String) -> CachedUserSession? {
        guard
            let data = UserDefaults.standard.data(forKey: sessionCacheKey),
            let session = try? JSONDecoder().decode(CachedUserSession.self, from: data),
            session.userID == userID
        else {
            return nil
        }
        return session
    }

    private static func clearCachedSession() {
        UserDefaults.standard.removeObject(forKey: sessionCacheKey)
    }

    private func syncProfile(_ user: APIUser?, into context: ModelContext?) {
        guard let user, let context else { return }
        UserProfile.sync(user, in: context)
    }
}
