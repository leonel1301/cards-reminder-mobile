import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var remoteID: String
    var firebaseUID: String
    var email: String?
    var displayName: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        remoteID: String,
        firebaseUID: String,
        email: String?,
        displayName: String?,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.remoteID = remoteID
        self.firebaseUID = firebaseUID
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    convenience init(from apiUser: APIUser) {
        self.init(
            remoteID: apiUser.id.uuidString,
            firebaseUID: apiUser.firebaseUID,
            email: apiUser.email,
            displayName: apiUser.displayName,
            createdAt: apiUser.createdAt,
            updatedAt: apiUser.updatedAt
        )
    }

    func update(from apiUser: APIUser) {
        firebaseUID = apiUser.firebaseUID
        email = apiUser.email
        displayName = apiUser.displayName
        createdAt = apiUser.createdAt
        updatedAt = apiUser.updatedAt
    }
}

extension UserProfile {
    @MainActor
    static func sync(_ apiUser: APIUser, in context: ModelContext) {
        let remoteID = apiUser.id.uuidString
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.remoteID == remoteID }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.update(from: apiUser)
        } else {
            let others = try? context.fetch(FetchDescriptor<UserProfile>())
            others?.forEach { context.delete($0) }
            context.insert(UserProfile(from: apiUser))
        }

        try? context.save()
    }

    @MainActor
    static func clearAll(in context: ModelContext) {
        let profiles = try? context.fetch(FetchDescriptor<UserProfile>())
        profiles?.forEach { context.delete($0) }
        try? context.save()
    }
}
