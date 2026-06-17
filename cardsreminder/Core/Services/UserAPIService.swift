import FirebaseAuth
import Foundation
import SwiftData

@Observable
@MainActor
final class UserAPIService {
    var isLoading = false
    var errorMessage: String?

    private(set) var loadedUserID: String?

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
                UserProfile.sync(user, in: context)
                loadedUserID = userID
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
