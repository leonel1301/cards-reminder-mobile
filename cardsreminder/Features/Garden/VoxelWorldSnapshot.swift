import Foundation

struct VoxelWorldSnapshot: Equatable {
    let treeCount: Int
    let livingAnimalCount: Int
    let starvedAnimalCount: Int
    /// Fully completed Learn sections; drives animal unlocks.
    let completedTracks: Int
    let unlockedAnimalKinds: [VoxelAnimalKind]
    let health: TreeHealth

    /// Visual and logical cap — payments beyond this do not add more trees.
    static let maxTreeCount = 10

    var stage: TreeHealth.Stage { health.stage }

    var cloudMessageKeys: [String] {
        var keys = [
            "cloud_comment_\(stage.rawValue)_1",
            "cloud_comment_\(stage.rawValue)_2"
        ]
        if starvedAnimalCount > 0 {
            keys.insert("cloud_comment_hungry", at: 0)
        } else if unlockedAnimalKinds.isEmpty {
            keys.append("cloud_comment_no_animals")
        }
        if treeCount == 0 {
            keys.append("cloud_comment_no_trees")
        }
        return keys
    }

    init(
        summary: DashboardSummary?,
        unlockedAnimals: [VoxelAnimalKind] = [],
        paymentCount: Int? = nil
    ) {
        health = TreeHealth(summary: summary)
        treeCount = min(Self.maxTreeCount, max(0, paymentCount ?? summary?.paid ?? 0))
        unlockedAnimalKinds = unlockedAnimals
        completedTracks = unlockedAnimals.count

        let pressure = (summary?.overdue ?? 0) + (summary?.urgent ?? 0)
        let unlockCount = unlockedAnimals.count
        if pressure == 0 {
            starvedAnimalCount = 0
        } else {
            starvedAnimalCount = min(unlockCount, pressure)
        }
        livingAnimalCount = max(0, unlockCount - starvedAnimalCount)
    }
}
