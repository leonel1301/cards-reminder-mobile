import SceneKit
import SwiftUI
import UIKit

struct WorldSceneView: UIViewRepresentable {
    var snapshot: VoxelWorldSnapshot
    var seed: Int = 0
    var isDark: Bool = false
    var allowsCameraControl: Bool = true
    var isActive: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.autoenablesDefaultLighting = false
        view.allowsCameraControl = allowsCameraControl
        view.rendersContinuously = isActive
        view.isPlaying = isActive
        context.coordinator.install(in: view, snapshot: snapshot, seed: seed, isDark: isDark)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.isPlaying = isActive
        uiView.rendersContinuously = isActive
        context.coordinator.sync(in: uiView, snapshot: snapshot, seed: seed, isDark: isDark)
    }

    static func dismantleUIView(_ uiView: SCNView, coordinator: Coordinator) {
        uiView.scene = nil
        uiView.isPlaying = false
    }

    final class Coordinator {
        private var current: VoxelWorldSnapshot?
        private var seed = 0
        private var isDark = false

        func install(in view: SCNView, snapshot: VoxelWorldSnapshot, seed: Int, isDark: Bool) {
            view.scene = VoxelWorldBuilder.makeScene(snapshot: snapshot, seed: seed, isDark: isDark)
            current = snapshot
            self.seed = seed
            self.isDark = isDark
        }

        func sync(in view: SCNView, snapshot: VoxelWorldSnapshot, seed: Int, isDark: Bool) {
            guard current != snapshot || self.seed != seed || self.isDark != isDark else { return }
            view.scene = VoxelWorldBuilder.makeScene(snapshot: snapshot, seed: seed, isDark: isDark)
            current = snapshot
            self.seed = seed
            self.isDark = isDark
        }
    }
}

enum VoxelWorldBuilder {
    static let block: Float = 0.28
    fileprivate static let grid = 12
    private static let height = 12
    private static let origin = Float(grid - 1) / 2
    private static let originY = Float(height - 1) / 2
    fileprivate static let surfaceY = height - 1
    fileprivate static var gridIndex: Int { grid - 1 }
    fileprivate static var surfaceIndex: Int { surfaceY }
    private static let waterY = surfaceY - 1
    private static let lakeFloorY = surfaceY - 2

    static func makeScene(snapshot: VoxelWorldSnapshot, seed: Int = 0, isDark: Bool) -> SCNScene {
        let recipe = VoxelWorldRecipe.make(seed: seed)
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        addLights(to: scene, snapshot: snapshot, isDark: isDark)
        addCamera(to: scene)

        let library = VoxelBlockLibrary(stage: snapshot.stage, block: block)

        let world = SCNNode()
        scene.rootNode.addChildNode(world)

        // The terrain and trees never move, so they are merged into one drawable.
        let solid = SCNNode()
        addTerrain(to: solid, library: library, recipe: recipe)
        addTrees(to: solid, snapshot: snapshot, library: library, recipe: recipe)
        world.addChildNode(solid.flattenedClone())

        addWater(to: world, library: library, recipe: recipe)
        addPlants(to: world, snapshot: snapshot, library: library, recipe: recipe)
        addAnimals(to: world, snapshot: snapshot, recipe: recipe)

        return scene
    }

    /// Offscreen still of the world, used when sharing a card of the garden.
    static func snapshotImage(
        snapshot: VoxelWorldSnapshot,
        seed: Int = 0,
        isDark: Bool,
        size: CGSize = CGSize(width: 1024, height: 1024)
    ) -> UIImage {
        let scene = makeScene(snapshot: snapshot, seed: seed, isDark: isDark)
        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        renderer.pointOfView = scene.rootNode.childNode(withName: "worldCamera", recursively: true)
        return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
    }

    private static func addLights(to scene: SCNScene, snapshot: VoxelWorldSnapshot, isDark: Bool) {
        let withered = snapshot.stage == .withered
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = isDark ? (withered ? 140 : 210) : (withered ? 280 : 420)
        ambient.light?.color = isDark
            ? UIColor(red: 0.55, green: 0.62, blue: 0.85, alpha: 1)
            : UIColor.white
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.intensity = isDark ? (withered ? 280 : 380) : 650
        if isDark {
            key.light?.color = withered
                ? UIColor(red: 0.72, green: 0.42, blue: 0.38, alpha: 1)
                : UIColor(red: 0.62, green: 0.74, blue: 1, alpha: 1)
        } else {
            key.light?.color = withered
                ? UIColor(red: 1, green: 0.78, blue: 0.62, alpha: 1)
                : UIColor(red: 1, green: 0.98, blue: 0.9, alpha: 1)
        }
        key.eulerAngles = SCNVector3(-0.7, 0.55, 0)
        scene.rootNode.addChildNode(key)
    }

    private static func addCamera(to scene: SCNScene) {
        let camera = SCNNode()
        camera.name = "worldCamera"
        camera.camera = SCNCamera()
        camera.camera?.fieldOfView = 34
        camera.camera?.wantsHDR = false
        camera.position = SCNVector3(7.2, 5.4, 7.2)
        camera.look(at: SCNVector3(0, 0.15, 0))
        scene.rootNode.addChildNode(camera)
    }

    private static func addTerrain(to world: SCNNode, library: VoxelBlockLibrary, recipe: VoxelWorldRecipe) {
        for x in 0..<grid {
            for z in 0..<grid {
                for y in 0..<height {
                    guard let solid = terrainBlock(x: x, y: y, z: z, recipe: recipe) else { continue }
                    let node = library.cube(solid)
                    node.position = worldCenter(x: x, y: y, z: z)
                    node.eulerAngles = upFace(x: x, y: y, z: z).standingEuler
                    world.addChildNode(node)
                }
            }
        }
    }

    private static func terrainBlock(
        x: Int,
        y: Int,
        z: Int,
        recipe: VoxelWorldRecipe
    ) -> VoxelBlockLibrary.Solid? {
        // The lake is carved out of the top face only: the bottom face stays closed.
        if recipe.isLake(x, z) && y != 0 {
            return y == lakeFloorY ? recipe.biome.lakeFloor : nil
        }

        let isPitWall = recipe.isShore(x, z) && (lakeFloorY...waterY).contains(y)
        let isShell = x == 0 || x == grid - 1 || z == 0 || z == grid - 1 || y == 0 || y == surfaceY
        guard isShell || isPitWall else { return nil }

        if isPitWall && y != surfaceY { return recipe.biome.pitWall }
        if recipe.isShore(x, z) && y == surfaceY { return recipe.biome.shore }
        if isAccentPatch(x: x, y: y, z: z, recipe: recipe) { return recipe.biome.accent }
        return recipe.biome.surface
    }

    /// Small 2x2 patches so the surface isn't a perfectly uniform slab.
    private static func isAccentPatch(x: Int, y: Int, z: Int, recipe: VoxelWorldRecipe) -> Bool {
        var random = VoxelRandom(
            seed: UInt64(bitPattern: Int64(recipe.seed))
                ^ UInt64(x / 2) &* 73_856_093
                ^ UInt64(y / 2) &* 19_349_663
                ^ UInt64(z / 2) &* 83_492_791
        )
        return random.next() % UInt64(recipe.biome.accentEvery) == 0
    }

    /// Which way is "up" for a block: it decides where the grass side of the block points.
    private static func upFace(x: Int, y: Int, z: Int) -> CubeFace {
        if y == surfaceY { return .top }
        if y == 0 { return .bottom }
        if x == 0 { return .minusX }
        if x == grid - 1 { return .plusX }
        if z == 0 { return .minusZ }
        return .plusZ
    }

    private static func addWater(to world: SCNNode, library: VoxelBlockLibrary, recipe: VoxelWorldRecipe) {
        guard recipe.lake != nil else { return }

        let surface = SCNNode()

        for x in 0..<grid {
            for z in 0..<grid where recipe.isLake(x, z) {
                let water = library.water()
                var position = worldCenter(x: x, y: waterY, z: z)
                position.y += water.drop
                water.node.position = position
                surface.addChildNode(water.node)
            }
        }

        let swell = SCNAction.moveBy(x: 0, y: CGFloat(block * 0.06), z: 0, duration: 2.8)
        swell.timingMode = .easeInEaseOut
        surface.runAction(.repeatForever(.sequence([swell, swell.reversed()])))
        world.addChildNode(surface)

        addLakeDetails(to: world, library: library, recipe: recipe)
    }

    private static func addLakeDetails(
        to world: SCNNode,
        library: VoxelBlockLibrary,
        recipe: VoxelWorldRecipe
    ) {
        guard let lake = recipe.lake else { return }

        var random = VoxelRandom(seed: UInt64(bitPattern: Int64(recipe.seed)) &+ 99)
        var cells: [(x: Int, z: Int)] = []
        for x in lake.minX...lake.maxX {
            for z in lake.minZ...lake.maxZ {
                cells.append((x, z))
            }
        }
        cells.shuffle(using: &random)

        let padCount: Int
        switch recipe.biome {
        case .meadow, .grove: padCount = min(3, cells.count)
        case .desert, .highlands: padCount = min(1, cells.count)
        }

        for pad in cells.prefix(padCount) {
            let node = library.lilyPad()
            var position = worldCenter(x: pad.x, y: waterY, z: pad.z)
            position.y += block * 0.4
            node.position = position
            world.addChildNode(node)
        }

        var shore: [(x: Int, z: Int)] = []
        for x in 0..<grid {
            for z in 0..<grid where recipe.isShore(x, z) {
                shore.append((x, z))
            }
        }
        shore.shuffle(using: &random)

        let caneCount = recipe.biome == .highlands ? 1 : 2
        for cane in shore.prefix(caneCount) {
            let node = library.plant(.sugarCane)
            var position = worldCenter(x: cane.x, y: surfaceY, z: cane.z)
            position.y += block / 2
            node.position = position
            world.addChildNode(node)
        }
    }

    private static func addPlants(
        to world: SCNNode,
        snapshot: VoxelWorldSnapshot,
        library: VoxelBlockLibrary,
        recipe: VoxelWorldRecipe
    ) {
        for face in CubeFace.allCases {
            var random = VoxelRandom(
                seed: UInt64(bitPattern: Int64(recipe.seed)) &+ 4_211 &+ UInt64(face.rawValue)
            )

            for spot in layout(on: face, snapshot: snapshot, recipe: recipe).plants {
                let voxel = face.voxel(u: spot.u, v: spot.v)
                let node = library.plant(recipe.biome.plant(roll: random.next()))
                node.position = surfacePoint(of: voxel, on: face)
                node.eulerAngles = face.standingEuler
                world.addChildNode(node)
            }
        }
    }

    private static func addTrees(
        to world: SCNNode,
        snapshot: VoxelWorldSnapshot,
        library: VoxelBlockLibrary,
        recipe: VoxelWorldRecipe
    ) {
        for face in CubeFace.allCases {
            for spot in layout(on: face, snapshot: snapshot, recipe: recipe).trees {
                addTree(to: world, face: face, u: spot.u, v: spot.v, library: library)
            }
        }
    }

    private static let trunkHeight = 4

    /// Oak canopy: a 5x5 layer, a 3x3 layer, and a plus-shaped crown.
    private static let canopy: [(step: Int, a: Int, b: Int)] = {
        var cells: [(step: Int, a: Int, b: Int)] = []

        for a in -2...2 {
            for b in -2...2 where !(abs(a) == 2 && abs(b) == 2) && !(a == 0 && b == 0) {
                cells.append((trunkHeight - 1, a, b))
            }
        }
        for a in -1...1 {
            for b in -1...1 where !(a == 0 && b == 0) {
                cells.append((trunkHeight, a, b))
            }
        }
        for a in -1...1 {
            for b in -1...1 where abs(a) + abs(b) <= 1 {
                cells.append((trunkHeight + 1, a, b))
            }
        }
        return cells
    }()

    private static func addTree(
        to world: SCNNode,
        face: CubeFace,
        u: Int,
        v: Int,
        library: VoxelBlockLibrary
    ) {
        let base = face.voxel(u: u, v: v)
        let tangent = face.tangents
        let orientation = face.standingEuler

        for step in 1...trunkHeight {
            let point = face.outward(from: base, steps: step)
            let log = library.cube(.log)
            log.position = worldCenter(x: point.x, y: point.y, z: point.z)
            log.eulerAngles = orientation
            world.addChildNode(log)
        }

        for cell in canopy {
            let point = face.outward(from: base, steps: cell.step)
            let leaves = library.cube(.leaves)
            leaves.position = worldCenter(
                x: point.x + tangent.0.x * cell.a + tangent.1.x * cell.b,
                y: point.y + tangent.0.y * cell.a + tangent.1.y * cell.b,
                z: point.z + tangent.0.z * cell.a + tangent.1.z * cell.b
            )
            world.addChildNode(leaves)
        }
    }

    private static func addAnimals(to world: SCNNode, snapshot: VoxelWorldSnapshot, recipe: VoxelWorldRecipe) {
        let unlocked = snapshot.unlockedAnimalKinds
        guard !unlocked.isEmpty else { return }

        let living = min(snapshot.livingAnimalCount, unlocked.count)

        for face in CubeFace.allCases {
            let spots = layout(on: face, snapshot: snapshot, recipe: recipe).animals
            for (index, spot) in spots.enumerated() {
                guard index < unlocked.count else { break }
                let kind = unlocked[index]
                let starved = index >= living
                let seed = recipe.seed &* 13 &+ face.rawValue &* 131 &+ index &* 17

                let mount = SCNNode()
                mount.position = surfacePoint(of: face.voxel(u: spot.u, v: spot.v), on: face)
                mount.eulerAngles = face.standingEuler
                mount.addChildNode(VoxelAnimalBuilder.make(kind: kind, starved: starved, seed: seed))
                world.addChildNode(mount)
            }
        }
    }

    /// Trees, animals and plants draw from one shuffled pool per face, so nothing overlaps.
    private static func layout(
        on face: CubeFace,
        snapshot: VoxelWorldSnapshot,
        recipe: VoxelWorldRecipe
    ) -> (trees: [FaceSpot], animals: [FaceSpot], plants: [FaceSpot]) {
        var random = VoxelRandom(
            seed: UInt64(bitPattern: Int64(recipe.seed)) &+ 991 &+ UInt64(face.rawValue)
        )
        let spots = occupancySpots(on: face, recipe: recipe).shuffled(using: &random)

        let treeCount = min(snapshot.treeCount, VoxelWorldSnapshot.maxTreeCount)
        let animalCount = snapshot.unlockedAnimalKinds.count

        return (
            trees: Array(spots.prefix(treeCount)),
            animals: Array(spots.dropFirst(treeCount).prefix(animalCount)),
            plants: Array(spots.dropFirst(treeCount + animalCount).prefix(12))
        )
    }

    private static func occupancySpots(on face: CubeFace, recipe: VoxelWorldRecipe) -> [FaceSpot] {
        var spots: [FaceSpot] = []
        for v in 2..<(grid - 2) {
            for u in 2..<(grid - 2) {
                if face == .top {
                    let voxel = face.voxel(u: u, v: v)
                    if recipe.isLake(voxel.x, voxel.z) || recipe.isShore(voxel.x, voxel.z) { continue }
                }
                spots.append(FaceSpot(u: u, v: v))
            }
        }
        return spots
    }

    /// The point right on top of a surface block, along that face's outward direction.
    private static func surfacePoint(of voxel: (x: Int, y: Int, z: Int), on face: CubeFace) -> SCNVector3 {
        let center = worldCenter(x: voxel.x, y: voxel.y, z: voxel.z)
        let lift = block / 2
        return SCNVector3(
            center.x + Float(face.normal.x) * lift,
            center.y + Float(face.normal.y) * lift,
            center.z + Float(face.normal.z) * lift
        )
    }

    private static func worldCenter(x: Int, y: Int, z: Int) -> SCNVector3 {
        SCNVector3(
            (Float(x) - origin) * block,
            (Float(y) - originY) * block,
            (Float(z) - origin) * block
        )
    }

}

private struct FaceSpot: Hashable {
    let u: Int
    let v: Int
}

private enum CubeFace: Int, CaseIterable {
    case top, bottom, plusX, minusX, plusZ, minusZ

    var normal: (x: Int, y: Int, z: Int) {
        switch self {
        case .top: (0, 1, 0)
        case .bottom: (0, -1, 0)
        case .plusX: (1, 0, 0)
        case .minusX: (-1, 0, 0)
        case .plusZ: (0, 0, 1)
        case .minusZ: (0, 0, -1)
        }
    }

    var tangents: ((x: Int, y: Int, z: Int), (x: Int, y: Int, z: Int)) {
        switch self {
        case .top, .bottom: ((1, 0, 0), (0, 0, 1))
        case .plusX, .minusX: ((0, 1, 0), (0, 0, 1))
        case .plusZ, .minusZ: ((1, 0, 0), (0, 1, 0))
        }
    }

    var standingEuler: SCNVector3 {
        switch self {
        case .top: SCNVector3(0, 0, 0)
        case .bottom: SCNVector3(Float.pi, 0, 0)
        case .plusX: SCNVector3(0, 0, -Float.pi / 2)
        case .minusX: SCNVector3(0, 0, Float.pi / 2)
        case .plusZ: SCNVector3(Float.pi / 2, 0, 0)
        case .minusZ: SCNVector3(-Float.pi / 2, 0, 0)
        }
    }

    func voxel(u: Int, v: Int) -> (x: Int, y: Int, z: Int) {
        let last = VoxelWorldBuilder.gridIndex
        let top = VoxelWorldBuilder.surfaceIndex
        switch self {
        case .top: return (u, top, v)
        case .bottom: return (u, 0, v)
        case .plusX: return (last, v, u)
        case .minusX: return (0, v, u)
        case .plusZ: return (u, v, last)
        case .minusZ: return (u, v, 0)
        }
    }

    func outward(from voxel: (x: Int, y: Int, z: Int), steps: Int) -> (x: Int, y: Int, z: Int) {
        (
            voxel.x + normal.x * steps,
            voxel.y + normal.y * steps,
            voxel.z + normal.z * steps
        )
    }
}

