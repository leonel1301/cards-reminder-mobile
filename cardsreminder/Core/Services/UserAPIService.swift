import Foundation
import SwiftData

@Observable
@MainActor
final class UserAPIService {
    var isLoading = false
    var errorMessage: String?

    private let api = APIService.shared

    func fetchProfile(into context: ModelContext) async {
        isLoading = true
        errorMessage = nil

        do {
            let user: APIUser = try await api.request(path: "/me")
            UserProfile.sync(user, in: context)
        } catch {
            if !error.isCancelled {
                errorMessage = error.localizedDescription
            }
        }

        isLoading = false
    }
}

private extension Error {
    var isCancelled: Bool {
        if self is CancellationError { return true }
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
