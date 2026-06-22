import FirebaseAuth
import Foundation
import SwiftUI

@Observable
@MainActor
final class FeedbackAPIService {
    var feedbacks: [APIFeedback] = []
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

    func fetchFeedbacks() async {
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
                let list: [APIFeedback] = try await api.request(path: "/me/feedback")
                withAnimation(SmoothRevealAnimation.motion) {
                    feedbacks = list
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

    @discardableResult
    func createFeedback(_ input: CreateFeedbackRequest) async -> APIFeedback? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let feedback: APIFeedback = try await api.request(path: "/feedback", method: "POST", body: input)
            withAnimation(SmoothRevealAnimation.motion) {
                feedbacks.insert(feedback, at: 0)
                contentRevision += 1
            }
            return feedback
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return nil
        }
    }

    @discardableResult
    func updateFeedback(id: UUID, _ input: UpdateFeedbackRequest) async -> APIFeedback? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let feedback: APIFeedback = try await api.request(
                path: "/feedback/\(id.uuidString)",
                method: "PATCH",
                body: input
            )
            if let index = feedbacks.firstIndex(where: { $0.id == id }) {
                withAnimation(SmoothRevealAnimation.motion) {
                    feedbacks[index] = feedback
                    contentRevision += 1
                }
            } else {
                withAnimation(SmoothRevealAnimation.motion) {
                    feedbacks.insert(feedback, at: 0)
                    contentRevision += 1
                }
            }
            return feedback
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return nil
        }
    }

    @discardableResult
    func deleteFeedback(id: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await api.requestVoid(path: "/feedback/\(id.uuidString)", method: "DELETE")
            withAnimation(SmoothRevealAnimation.motion) {
                feedbacks.removeAll { $0.id == id }
                contentRevision += 1
            }
            return true
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return false
        }
    }

    func resetSession() {
        fetchTask?.cancel()
        fetchTask = nil
        feedbacks = []
        loadedUserID = nil
        contentRevision = 0
        errorMessage = nil
        isLoading = false
    }
}
