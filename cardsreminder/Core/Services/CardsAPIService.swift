import FirebaseAuth
import Foundation

@Observable
@MainActor
final class CardsAPIService {
    var cards: [APICard] = []
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

    var activeCards: [APICard] {
        cards.filter(\.isActive)
    }

    func resetSession() {
        fetchTask?.cancel()
        fetchTask = nil
        cards = []
        loadedUserID = nil
        errorMessage = nil
        isLoading = false
    }

    func fetchCards() async {
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
                let cardsList: [APICard] = try await api.request(path: "/cards")
                cards = cardsList.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
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
            cards.removeAll { $0.id == id }
            return true
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return false
        }
    }
}
