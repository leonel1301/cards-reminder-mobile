import FirebaseAuth
import Foundation
import SwiftUI

struct LessonProgressListResponse: Codable, Sendable, Equatable {
    let lessonIDs: [String]
    let completedCount: Int

    enum CodingKeys: String, CodingKey {
        case lessonIDs = "lesson_ids"
        case completedCount = "completed_count"
    }
}

struct LessonProgressRecord: Codable, Sendable, Equatable, Identifiable {
    let id: UUID
    let userID: UUID
    let lessonID: String
    let completedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case lessonID = "lesson_id"
        case completedAt = "completed_at"
    }
}

@Observable
@MainActor
final class LearnAPIService {
    private(set) var completedLessonIDs: Set<String> = []
    private(set) var isLoading = false
    private(set) var contentRevision = 0
    private(set) var loadedUserID: String?
    var errorMessage: String?

    private let api = APIService.shared
    private var fetchTask: Task<Void, Never>?

    var completedCount: Int { completedLessonIDs.count }

    var completedTracks: [LearnTrack] {
        LearnTrack.allCases.filter(isTrackCompleted)
    }

    /// One animal per fully completed Learn section, in catalog order.
    var unlockedAnimalKinds: [VoxelAnimalKind] {
        completedTracks.compactMap { track in
            guard let index = LearnTrack.allCases.firstIndex(of: track) else { return nil }
            return VoxelAnimalKind.reward(forCompletedIndex: index)
        }
    }

    func isCompleted(_ lessonID: String) -> Bool {
        completedLessonIDs.contains(lessonID)
    }

    func completedCount(in track: LearnTrack) -> Int {
        LearnCatalog.lessons(in: track).filter { completedLessonIDs.contains($0.id) }.count
    }

    func isTrackCompleted(_ track: LearnTrack) -> Bool {
        let lessons = LearnCatalog.lessons(in: track)
        guard !lessons.isEmpty else { return false }
        return lessons.allSatisfy { completedLessonIDs.contains($0.id) }
    }

    func resetSession() {
        fetchTask?.cancel()
        fetchTask = nil
        completedLessonIDs = []
        isLoading = false
        errorMessage = nil
        contentRevision += 1
        loadedUserID = nil
    }

    func fetchProgress() async {
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

            // Show this user's local cache immediately, never another account's.
            if loadedUserID != userID {
                apply(LearnProgressStore.ids(forUserID: userID), userID: userID)
            }

            do {
                let response: LessonProgressListResponse = try await api.request(path: "/me/lessons")
                apply(Set(response.lessonIDs), userID: userID)
            } catch {
                if completedLessonIDs.isEmpty {
                    apply(LearnProgressStore.ids(forUserID: userID), userID: userID)
                }
                APIErrorHandling.handle(error) { errorMessage = $0 }
            }
        }

        fetchTask = task
        await task.value
    }

    @discardableResult
    func markCompleted(_ lessonID: String) async -> Bool {
        guard let userID = Auth.auth().currentUser?.uid else { return false }

        let previous = completedLessonIDs
        var optimistic = completedLessonIDs
        optimistic.insert(lessonID)
        apply(optimistic, userID: userID)
        Haptics.success()

        do {
            let _: LessonProgressRecord = try await api.request(
                path: "/me/lessons/\(lessonID)",
                method: "PUT"
            )
            return true
        } catch {
            apply(previous, userID: userID)
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return false
        }
    }

    @discardableResult
    func unmarkCompleted(_ lessonID: String) async -> Bool {
        guard let userID = Auth.auth().currentUser?.uid else { return false }

        let previous = completedLessonIDs
        var optimistic = completedLessonIDs
        optimistic.remove(lessonID)
        apply(optimistic, userID: userID)

        do {
            try await api.requestVoid(path: "/me/lessons/\(lessonID)", method: "DELETE")
            return true
        } catch {
            apply(previous, userID: userID)
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return false
        }
    }

    func toggleCompleted(_ lessonID: String) async {
        if isCompleted(lessonID) {
            _ = await unmarkCompleted(lessonID)
        } else {
            _ = await markCompleted(lessonID)
        }
    }

    private func apply(_ ids: Set<String>, userID: String) {
        withAnimation(SmoothRevealAnimation.motion) {
            completedLessonIDs = ids
            loadedUserID = userID
            contentRevision += 1
        }
        LearnProgressStore.setCachedRaw(LearnProgressStore.raw(from: ids), forUserID: userID)
    }
}
