import FirebaseAuth
import Foundation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class UserAPIService {
    var isLoading = false
    var errorMessage: String?

    private(set) var loadedUserID: String?
    private(set) var contentRevision = 0

    private let api = APIService.shared
    private var fetchTask: Task<Void, Never>?

    var hasLoaded: Bool {
        guard let loadedUserID, loadedUserID == Auth.auth().currentUser?.uid else {
            return false
        }
        return true
    }

    func resetSession() {
        fetchTask?.cancel()
        fetchTask = nil
        loadedUserID = nil
        contentRevision = 0
        errorMessage = nil
        isLoading = false
    }

    func fetchProfile(into context: ModelContext) async {
        guard let userID = Auth.auth().currentUser?.uid else {
            resetSession()
            return
        }

        if let fetchTask {
            await fetchTask.value
            return
        }

        let task = Task { @MainActor in
            isLoading = true
            errorMessage = nil

            do {
                let user: APIUser = try await api.request(path: "/me")
                withAnimation(SmoothRevealAnimation.motion) {
                    UserProfile.sync(user, in: context)
                    loadedUserID = userID
                    contentRevision += 1
                }
            } catch {
                APIErrorHandling.handle(error) { errorMessage = $0 }
            }

            isLoading = false
            fetchTask = nil
        }

        fetchTask = task
        await task.value
    }
}
