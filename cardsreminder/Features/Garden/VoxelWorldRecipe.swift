import Foundation

enum VoxelBiome: Int, CaseIterable, Equatable {
    /// Grass top, the original look.
    case meadow
    /// Sand dunes with a possible oasis.
    case desert
    /// Packed dirt with grass patches.
    case grove
    /// Stone highlands with pockets of grass.
    case highlands
}

struct VoxelLake: Equatable {
    let minX: Int
    let maxX: Int
    let minZ: Int
    let maxZ: Int

    func contains(x: Int, z: Int) -> Bool {
        (minX...maxX).contains(x) && (minZ...maxZ).contains(z)
    }
}

/// Cosmetic layout of the voxel cube: biome, water, and the RNG seed used to
/// place things. Tree and animal *counts* still come from `VoxelWorldSnapshot`.
struct VoxelWorldRecipe: Equatable {
    /// Matches the 12³ cube in `VoxelWorldBuilder`.
    static let grid = 12

    let seed: Int
    let biome: VoxelBiome
    let lake: VoxelLake?

    /// The world shipped with the app: meadow and a 4×4 lake on the top face.
    static let classic = VoxelWorldRecipe(
        seed: 0,
        biome: .meadow,
        lake: VoxelLake(minX: 6, maxX: 9, minZ: 6, maxZ: 9)
    )

    static func make(seed: Int) -> VoxelWorldRecipe {
        if seed == 0 { return classic }

        let biome = biome(for: seed)
        return VoxelWorldRecipe(
            seed: seed,
            biome: biome,
            lake: lake(for: seed, biome: biome)
        )
    }

    /// Picks a new seed whose biome is different from the current one, so a
    /// rebuild always changes the soil instead of rerolling the same meadow.
    static func nextSeed(after current: Int, draw: () -> Int = { Int.random(in: 1...Int.max) }) -> Int {
        let currentBiome = make(seed: current).biome

        for _ in 0..<32 {
            let candidate = draw()
            if candidate != current, make(seed: candidate).biome != currentBiome {
                return candidate
            }
        }

        var candidate = current == Int.max ? 1 : current + 1
        while make(seed: candidate).biome == currentBiome {
            candidate = candidate == Int.max ? 1 : candidate + 1
        }
        return candidate
    }

    func isLake(_ x: Int, _ z: Int) -> Bool {
        lake?.contains(x: x, z: z) ?? false
    }

    func isShore(_ x: Int, _ z: Int) -> Bool {
        guard !isLake(x, z) else { return false }
        for dx in -1...1 {
            for dz in -1...1 where dx != 0 || dz != 0 {
                if isLake(x + dx, z + dz) { return true }
            }
        }
        return false
    }

    private static func biome(for seed: Int) -> VoxelBiome {
        let cases = VoxelBiome.allCases
        return cases[Int(UInt(bitPattern: seed) % UInt(cases.count))]
    }

    private static func lake(for seed: Int, biome: VoxelBiome) -> VoxelLake? {
        var random = VoxelRandom(seed: UInt64(bitPattern: Int64(seed)) &* 0x9E37_79B9 &+ 3)
        let roll = random.next()

        let size: Int
        switch biome {
        case .meadow, .grove:
            size = 3 + Int(roll % 2)
        case .desert:
            guard roll % 5 != 0 else { return nil }
            size = 2
        case .highlands:
            guard roll % 2 == 0 else { return nil }
            size = 2
        }

        let originSpan = Self.grid - 2 - size - 2
        guard originSpan > 0 else { return nil }

        let originX = 2 + Int(random.next() % UInt64(originSpan))
        let originZ = 2 + Int(random.next() % UInt64(originSpan))
        return VoxelLake(
            minX: originX,
            maxX: originX + size - 1,
            minZ: originZ,
            maxZ: originZ + size - 1
        )
    }
}

extension VoxelBiome {
    var surface: VoxelBlockLibrary.Solid {
        switch self {
        case .meadow: .grass
        case .desert: .sand
        case .grove: .dirt
        case .highlands: .stone
        }
    }

    var accent: VoxelBlockLibrary.Solid {
        switch self {
        case .meadow: .stone
        case .desert: .stone
        case .grove: .grass
        case .highlands: .grass
        }
    }

    /// Lower is denser. Meadow keeps the original 1-in-14 boulders.
    var accentEvery: Int {
        switch self {
        case .meadow: 14
        case .desert: 18
        case .grove: 10
        case .highlands: 8
        }
    }

    var shore: VoxelBlockLibrary.Solid {
        switch self {
        case .meadow, .desert: .sand
        case .grove: .dirt
        case .highlands: .stone
        }
    }

    var pitWall: VoxelBlockLibrary.Solid {
        switch self {
        case .meadow, .grove: .dirt
        case .desert: .sand
        case .highlands: .stone
        }
    }

    var lakeFloor: VoxelBlockLibrary.Solid {
        switch self {
        case .meadow, .desert: .sand
        case .grove: .dirt
        case .highlands: .stone
        }
    }

    func plant(roll: UInt64) -> VoxelBlockLibrary.Plant {
        switch self {
        case .meadow:
            switch roll % 9 {
            case 0, 1: .poppy
            case 2, 3: .dandelion
            default: .tallGrass
            }
        case .desert:
            .tallGrass
        case .grove:
            roll % 8 < 2 ? .poppy : .tallGrass
        case .highlands:
            roll % 8 < 2 ? .dandelion : .tallGrass
        }
    }
}
