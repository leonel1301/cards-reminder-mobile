import SceneKit
import UIKit

struct VoxelRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &* 2_685_821_657_736_338_717 &+ 1
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// Builds and caches the pixel-art blocks the voxel world is made of.
final class VoxelBlockLibrary {
    enum Solid: Hashable {
        case grass
        case dirt
        case stone
        case sand
        case log
        case leaves
    }

    enum Plant: Hashable {
        case tallGrass
        case poppy
        case dandelion
        case sugarCane
    }

    private let block: Float
    private let stage: TreeHealth.Stage
    private var solids: [Solid: SCNGeometry] = [:]
    private var plants: [Plant: SCNMaterial] = [:]
    private var waterGeometry: SCNGeometry?
    private var lilyGeometry: SCNGeometry?

    init(stage: TreeHealth.Stage, block: Float) {
        self.stage = stage
        self.block = block
    }

    // MARK: - Blocks

    func cube(_ solid: Solid) -> SCNNode {
        SCNNode(geometry: geometry(for: solid))
    }

    /// Water sits slightly below the surrounding surface, the way a Minecraft lake does.
    func water() -> (node: SCNNode, drop: Float) {
        let height = block * 0.78
        if waterGeometry == nil {
            let box = SCNBox(
                width: CGFloat(block),
                height: CGFloat(height),
                length: CGFloat(block),
                chamferRadius: 0
            )
            let water = material(texture(.water))
            water.transparency = 0.78
            water.writesToDepthBuffer = true
            box.materials = [water]
            waterGeometry = box
        }
        return (SCNNode(geometry: waterGeometry!), (height - block) / 2)
    }

    func lilyPad() -> SCNNode {
        if lilyGeometry == nil {
            let plane = SCNPlane(width: CGFloat(block * 0.9), height: CGFloat(block * 0.9))
            let pad = material(texture(.lilyPad))
            pad.isDoubleSided = true
            plane.materials = [pad]
            lilyGeometry = plane
        }
        let node = SCNNode(geometry: lilyGeometry!)
        node.eulerAngles.x = -Float.pi / 2
        return node
    }

    /// Crossed planes, the way Minecraft draws grass and flowers.
    func plant(_ plant: Plant) -> SCNNode {
        let material = plantMaterial(plant)
        let tall = plant == .sugarCane
        let size = CGFloat(block * (tall ? 1.9 : 0.95))
        let root = SCNNode()

        for angle in [Float.zero, Float.pi / 2] {
            let plane = SCNPlane(width: CGFloat(block * 0.95), height: size)
            plane.materials = [material]
            let leaf = SCNNode(geometry: plane)
            leaf.position.y = Float(size) / 2
            leaf.eulerAngles.y = angle
            root.addChildNode(leaf)
        }
        return root
    }

    // MARK: - Geometry

    private func geometry(for solid: Solid) -> SCNGeometry {
        if let cached = solids[solid] { return cached }

        let box = SCNBox(
            width: CGFloat(block),
            height: CGFloat(block),
            length: CGFloat(block),
            chamferRadius: 0
        )

        switch solid {
        case .grass:
            let side = material(texture(.grassSide))
            box.materials = [side, side, side, side, material(texture(.grassTop)), material(texture(.dirt))]
        case .dirt:
            box.materials = [material(texture(.dirt))]
        case .stone:
            box.materials = [material(texture(.stone))]
        case .sand:
            box.materials = [material(texture(.sand))]
        case .log:
            let bark = material(texture(.logSide))
            let rings = material(texture(.logTop))
            box.materials = [bark, bark, bark, bark, rings, rings]
        case .leaves:
            box.materials = [material(texture(.leaves))]
        }

        solids[solid] = box
        return box
    }

    private func plantMaterial(_ plant: Plant) -> SCNMaterial {
        if let cached = plants[plant] { return cached }

        let pattern: Pattern
        switch plant {
        case .tallGrass: pattern = .tallGrass
        case .poppy: pattern = .poppy
        case .dandelion: pattern = .dandelion
        case .sugarCane: pattern = .sugarCane
        }

        let made = material(texture(pattern))
        made.isDoubleSided = true
        made.writesToDepthBuffer = true
        made.blendMode = .alpha
        if plant == .sugarCane {
            // The cane is two blocks tall, so the segment texture repeats instead of stretching.
            made.diffuse.wrapT = .repeat
            made.diffuse.contentsTransform = SCNMatrix4MakeScale(1, 2, 1)
        }
        plants[plant] = made
        return made
    }

    private func material(_ image: UIImage) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = image
        material.diffuse.magnificationFilter = .nearest
        material.diffuse.minificationFilter = .nearest
        material.diffuse.mipFilter = .nearest
        material.roughness.contents = 1
        material.metalness.contents = 0
        return material
    }

    // MARK: - Textures

    private enum Pattern: Hashable {
        case grassTop
        case grassSide
        case dirt
        case stone
        case sand
        case water
        case logSide
        case logTop
        case leaves
        case lilyPad
        case tallGrass
        case poppy
        case dandelion
        case sugarCane
    }

    private static var textureCache: [String: UIImage] = [:]

    private func texture(_ pattern: Pattern) -> UIImage {
        let key = "\(stage.rawValue)-\(pattern)"
        if let cached = Self.textureCache[key] { return cached }

        let image = draw(pattern)
        Self.textureCache[key] = image
        return image
    }

    private func draw(_ pattern: Pattern) -> UIImage {
        switch pattern {
        case .grassTop:
            return noise(base: grass, shades: [grass.shifted(0.07), grass.shifted(-0.06), grass.shifted(-0.12)], seed: 11)
        case .grassSide:
            return grassSide()
        case .dirt:
            return noise(base: dirt, shades: [dirt.shifted(0.06), dirt.shifted(-0.07), dirt.shifted(-0.13)], seed: 23)
        case .stone:
            let stone = UIColor(red: 0.48, green: 0.48, blue: 0.47, alpha: 1)
            return noise(base: stone, shades: [stone.shifted(0.07), stone.shifted(-0.07), stone.shifted(-0.14)], seed: 31)
        case .sand:
            let sand = UIColor(red: 0.85, green: 0.79, blue: 0.58, alpha: 1)
            return noise(base: sand, shades: [sand.shifted(0.05), sand.shifted(-0.05)], seed: 37)
        case .water:
            let water = UIColor(red: 0.21, green: 0.43, blue: 0.85, alpha: 1)
            return noise(base: water, shades: [water.shifted(0.08), water.shifted(-0.06)], seed: 41, density: 0.22)
        case .logSide:
            return logSide()
        case .logTop:
            return logTop()
        case .leaves:
            return leavesTexture()
        case .lilyPad:
            return lilyPadTexture()
        case .tallGrass:
            return tallGrassTexture()
        case .poppy:
            return flowerTexture(bloom: UIColor(red: 0.78, green: 0.17, blue: 0.15, alpha: 1))
        case .dandelion:
            return flowerTexture(bloom: UIColor(red: 0.95, green: 0.82, blue: 0.2, alpha: 1))
        case .sugarCane:
            return sugarCaneTexture()
        }
    }

    private func noise(
        base: UIColor,
        shades: [UIColor],
        seed: UInt64,
        density: Double = 0.45,
        size: Int = 16
    ) -> UIImage {
        image(size: size) { painter in
            painter.fill(0, 0, size, size, base)
            var random = VoxelRandom(seed: seed)
            for y in 0..<size {
                for x in 0..<size {
                    guard Double.random(in: 0...1, using: &random) < density else { continue }
                    let shade = shades[Int(random.next() % UInt64(shades.count))]
                    painter.fill(x, y, 1, 1, shade)
                }
            }
        }
    }

    private func grassSide() -> UIImage {
        image(size: 16) { painter in
            painter.fill(0, 0, 16, 16, dirt)
            var random = VoxelRandom(seed: 53)
            for y in 0..<16 {
                for x in 0..<16 where Double.random(in: 0...1, using: &random) < 0.4 {
                    painter.fill(x, y, 1, 1, dirt.shifted(Bool.random(using: &random) ? 0.06 : -0.08))
                }
            }
            painter.fill(0, 0, 16, 3, grass)
            for x in 0..<16 {
                let depth = 3 + Int(random.next() % 3)
                painter.fill(x, 3, 1, depth - 3, grass.shifted(-0.05))
            }
            for x in 0..<16 where Double.random(in: 0...1, using: &random) < 0.35 {
                painter.fill(x, 0, 1, 1, grass.shifted(0.08))
            }
        }
    }

    private func logSide() -> UIImage {
        let bark = UIColor(red: 0.42, green: 0.31, blue: 0.18, alpha: 1)
        return image(size: 16) { painter in
            painter.fill(0, 0, 16, 16, bark)
            var random = VoxelRandom(seed: 67)
            for x in 0..<16 {
                let shade = bark.shifted(Double.random(in: -0.1...0.08, using: &random))
                painter.fill(x, 0, 1, 16, shade)
            }
            for _ in 0..<10 {
                let x = Int(random.next() % 16)
                let y = Int(random.next() % 12)
                painter.fill(x, y, 1, 2 + Int(random.next() % 3), bark.shifted(-0.14))
            }
        }
    }

    private func logTop() -> UIImage {
        let bark = UIColor(red: 0.42, green: 0.31, blue: 0.18, alpha: 1)
        let core = UIColor(red: 0.62, green: 0.47, blue: 0.27, alpha: 1)
        return image(size: 16) { painter in
            painter.fill(0, 0, 16, 16, bark)
            painter.fill(2, 2, 12, 12, core)
            painter.fill(4, 4, 8, 8, core.shifted(-0.08))
            painter.fill(6, 6, 4, 4, core.shifted(0.06))
            painter.fill(7, 7, 2, 2, core.shifted(-0.14))
        }
    }

    private func leavesTexture() -> UIImage {
        let leaf = self.leaf
        return image(size: 16) { painter in
            painter.fill(0, 0, 16, 16, leaf.shifted(-0.1))
            var random = VoxelRandom(seed: 71)
            for y in 0..<16 {
                for x in 0..<16 {
                    let roll = Double.random(in: 0...1, using: &random)
                    if roll < 0.42 {
                        painter.fill(x, y, 1, 1, leaf)
                    } else if roll < 0.56 {
                        painter.fill(x, y, 1, 1, leaf.shifted(0.09))
                    } else if roll < 0.62 {
                        painter.fill(x, y, 1, 1, leaf.shifted(-0.2))
                    }
                }
            }
        }
    }

    private func lilyPadTexture() -> UIImage {
        let pad = UIColor(red: 0.24, green: 0.55, blue: 0.24, alpha: 1)
        return image(size: 16, opaque: false) { painter in
            painter.fill(3, 2, 10, 12, pad)
            painter.fill(2, 4, 12, 8, pad)
            painter.fill(4, 1, 8, 14, pad)
            painter.fill(7, 8, 2, 7, .clear)
            painter.fill(6, 5, 4, 4, pad.shifted(-0.1))
        }
    }

    private func tallGrassTexture() -> UIImage {
        let blade = grass.shifted(-0.04)
        return image(size: 16, opaque: false) { painter in
            var random = VoxelRandom(seed: 83)
            for x in [2, 5, 8, 11, 13] {
                let height = 7 + Int(random.next() % 6)
                painter.fill(x, 16 - height, 1, height, blade.shifted(Double.random(in: -0.08...0.08, using: &random)))
                painter.fill(x + 1, 16 - height / 2, 1, height / 2, blade.shifted(-0.06))
            }
            painter.fill(0, 15, 16, 1, blade.shifted(-0.1))
        }
    }

    private func flowerTexture(bloom: UIColor) -> UIImage {
        let stem = UIColor(red: 0.24, green: 0.5, blue: 0.19, alpha: 1)
        return image(size: 16, opaque: false) { painter in
            painter.fill(7, 7, 2, 9, stem)
            painter.fill(5, 10, 2, 2, stem)
            painter.fill(9, 12, 2, 2, stem)
            painter.fill(5, 3, 6, 4, bloom)
            painter.fill(6, 2, 4, 1, bloom)
            painter.fill(4, 4, 1, 2, bloom.shifted(-0.08))
            painter.fill(11, 4, 1, 2, bloom.shifted(-0.08))
            painter.fill(7, 4, 2, 2, bloom.shifted(0.22))
        }
    }

    private func sugarCaneTexture() -> UIImage {
        let cane = UIColor(red: 0.53, green: 0.75, blue: 0.4, alpha: 1)
        return image(size: 16, opaque: false) { painter in
            painter.fill(6, 0, 4, 16, cane)
            painter.fill(6, 4, 4, 1, cane.shifted(-0.14))
            painter.fill(6, 10, 4, 1, cane.shifted(-0.14))
            painter.fill(3, 2, 3, 1, cane.shifted(-0.06))
            painter.fill(10, 8, 3, 1, cane.shifted(-0.06))
        }
    }

    // MARK: - Stage palette

    private var grass: UIColor {
        switch stage {
        case .withered: UIColor(red: 0.56, green: 0.47, blue: 0.22, alpha: 1)
        case .struggling: UIColor(red: 0.55, green: 0.6, blue: 0.27, alpha: 1)
        case .dormant: UIColor(red: 0.45, green: 0.65, blue: 0.31, alpha: 1)
        default: UIColor(red: 0.33, green: 0.7, blue: 0.27, alpha: 1)
        }
    }

    private var leaf: UIColor {
        switch stage {
        case .withered: UIColor(red: 0.44, green: 0.39, blue: 0.18, alpha: 1)
        case .struggling: UIColor(red: 0.5, green: 0.6, blue: 0.21, alpha: 1)
        default: UIColor(red: 0.2, green: 0.58, blue: 0.19, alpha: 1)
        }
    }

    private var dirt: UIColor {
        UIColor(red: 0.51, green: 0.36, blue: 0.23, alpha: 1)
    }

    // MARK: - Drawing

    private struct PixelPainter {
        let context: CGContext

        func fill(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: UIColor) {
            guard width > 0, height > 0 else { return }
            let rect = CGRect(x: x, y: y, width: width, height: height)
            if color == .clear {
                context.setBlendMode(.clear)
                context.fill(rect)
                context.setBlendMode(.normal)
                return
            }
            context.setFillColor(color.cgColor)
            context.fill(rect)
        }
    }

    private func image(size: Int, opaque: Bool = true, _ body: (PixelPainter) -> Void) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = opaque
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: size, height: size),
            format: format
        )
        return renderer.image { context in
            context.cgContext.interpolationQuality = .none
            body(PixelPainter(context: context.cgContext))
        }
    }
}

private extension UIColor {
    /// Shifts brightness, keeping the hue, so one base colour can make a whole pixel palette.
    func shifted(_ amount: Double) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        return UIColor(
            hue: hue,
            saturation: saturation,
            brightness: min(1, max(0.05, brightness + CGFloat(amount))),
            alpha: alpha
        )
    }
}
