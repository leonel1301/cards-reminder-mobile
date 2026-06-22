import FirebaseAuth
import Foundation
import SwiftUI

@Observable
@MainActor
final class OwnersAPIService {
    var owners: [APIOwner] = []
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

    var selfOwner: APIOwner? {
        owners.first(where: \.isSelf)
    }

    func fetchOwners() async {
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
            defer {
                isLoading = false
                fetchTask = nil
            }

            do {
                let list: [APIOwner] = try await api.request(path: "/owners")
                withAnimation(SmoothRevealAnimation.motion) {
                    owners = list
                    sortOwners()
                    loadedUserID = userID
                    contentRevision += 1
                }
            } catch {
                APIErrorHandling.handle(error) { errorMessage = $0 }
            }
        }

        fetchTask = task
        await task.value
    }

    @discardableResult
    func createOwner(_ input: CreateOwnerRequest) async -> APIOwner? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let owner: APIOwner = try await api.request(path: "/owners", method: "POST", body: input)
            owners.append(owner)
            sortOwners()
            return owner
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return nil
        }
    }

    @discardableResult
    func updateOwner(id: UUID, _ input: UpdateOwnerRequest) async -> APIOwner? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let owner: APIOwner = try await api.request(path: "/owners/\(id.uuidString)", method: "PATCH", body: input)
            if let index = owners.firstIndex(where: { $0.id == id }) {
                owners[index] = owner
            } else {
                owners.append(owner)
            }
            sortOwners()
            return owner
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return nil
        }
    }

    @discardableResult
    func deleteOwner(id: UUID) async -> Bool {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            try await api.requestVoid(path: "/owners/\(id.uuidString)", method: "DELETE")
            owners.removeAll { $0.id == id }
            return true
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return false
        }
    }

    func ownerName(for id: UUID) -> String? {
        owners.first(where: { $0.id == id })?.displayName
    }

    func resetSession() {
        fetchTask?.cancel()
        fetchTask = nil
        owners = []
        loadedUserID = nil
        contentRevision = 0
        errorMessage = nil
        isLoading = false
    }

    private func sortOwners() {
        owners.sort { lhs, rhs in
            if lhs.isSelf != rhs.isSelf { return lhs.isSelf && !rhs.isSelf }
            return lhs.name.localizedCompare(rhs.name) == .orderedAscending
        }
    }
}
