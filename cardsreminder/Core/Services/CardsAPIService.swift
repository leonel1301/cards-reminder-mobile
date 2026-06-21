import FirebaseAuth
import Foundation
import SwiftUI

@Observable
@MainActor
final class CardsAPIService {
    var cards: [APICard] = []
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

    var activeCards: [APICard] {
        cards.filter(\.isActive)
    }

    func resetSession() {
        cancelInFlightRequests()
        cards = []
        loadedUserID = nil
        contentRevision = 0
        errorMessage = nil
        isLoading = false
    }

    func cancelInFlightRequests() {
        fetchTask?.cancel()
    }

    func resumeOnForeground() async {
        if hasLoaded {
            errorMessage = nil
            await fetchCards(silentUnlessEmpty: true, maxAttempts: 2)
        } else if fetchTask == nil {
            await fetchCards()
        }
    }

    func fetchCards(silentUnlessEmpty: Bool = true, maxAttempts: Int = 1) async {
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
            if !silentUnlessEmpty || cards.isEmpty {
                errorMessage = nil
            }

            defer {
                isLoading = false
                fetchTask = nil
            }

            let attempts = max(1, maxAttempts)

            for attempt in 1...attempts {
                if Task.isCancelled { return }

                do {
                    let cardsList: [APICard] = try await api.request(path: "/cards")
                    withAnimation(SmoothRevealAnimation.motion) {
                        cards = cardsList.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
                        loadedUserID = userID
                        contentRevision += 1
                    }
                    errorMessage = nil
                    return
                } catch {
                    guard !error.isRequestCancelled else { return }

                    if attempt < attempts {
                        try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                        continue
                    }

                    guard !silentUnlessEmpty || cards.isEmpty else { return }
                    APIErrorHandling.handle(error) { errorMessage = $0 }
                }
            }
        }

        fetchTask = task
        await task.value
    }

    func fetchCard(id: UUID) async -> APICard? {
        do {
            return try await api.request(path: "/cards/\(id.uuidString)")
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return nil
        }
    }

    @discardableResult
    func createCard(_ input: CreateCardRequest) async -> APICard? {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let card: APICard = try await api.request(path: "/cards", method: "POST", body: input)
            cards.append(card)
            cards.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
            return card
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return nil
        }
    }

    @discardableResult
    func updateCard(id: UUID, _ input: UpdateCardRequest) async -> APICard? {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let card: APICard = try await api.request(path: "/cards/\(id.uuidString)", method: "PATCH", body: input)
            if let index = cards.firstIndex(where: { $0.id == id }) {
                cards[index] = card
            } else {
                cards.append(card)
            }
            cards.sort { $0.name.localizedCompare($1.name) == .orderedAscending }
            return card
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return nil
        }
    }

    @discardableResult
    func deleteCard(id: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            try await api.requestVoid(path: "/cards/\(id.uuidString)", method: "DELETE")
            withAnimation(SmoothRevealAnimation.motion) {
                cards.removeAll { $0.id == id }
                contentRevision += 1
            }
            return true
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return false
        }
    }
}

private extension Error {
    var isRequestCancelled: Bool {
        if self is CancellationError { return true }
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
