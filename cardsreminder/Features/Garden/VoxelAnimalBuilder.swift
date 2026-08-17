import SceneKit
import UIKit

enum VoxelAnimalKind: Int, CaseIterable {
    case sheep, cow, pig, chicken, rabbit, bee

    var titleKey: String { "learn_animal_\(rawName)" }

    private var rawName: String {
        switch self {
        case .sheep: "sheep"
        case .cow: "cow"
        case .pig: "pig"
        case .chicken: "chicken"
        case .rabbit: "rabbit"
        case .bee: "bee"
        }
    }

    /// Animal unlocked by the nth fully completed Learn section (0-based).
    static func reward(forCompletedIndex index: Int) -> VoxelAnimalKind {
        let kinds = allCases
        guard !kinds.isEmpty else { return .sheep }
        let safeIndex = max(0, index)
        return kinds[safeIndex % kinds.count]
    }

    var gait: VoxelAnimalGait {
        switch self {
        case .rabbit: .hop
        case .bee: .fly
        default: .walk
        }
    }

    var speed: Float {
        switch self {
        case .sheep: 0.09
        case .cow: 0.07
        case .pig: 0.11
        case .chicken: 0.14
        case .rabbit: 0.16
        case .bee: 0.2
        }
    }
}

enum VoxelAnimalGait {
    case walk
    case hop
    case fly
}

enum VoxelAnimalBuilder {
    /// One Minecraft texture pixel. A mob block is 16 of these.
    private static var px: Float { VoxelWorldBuilder.block / 16 * 1.15 }

    static func make(kind: VoxelAnimalKind, starved: Bool, seed: Int, preview: Bool = false) -> SCNNode {
        let root = SCNNode()
        let bounce = SCNNode()
        root.addChildNode(bounce)

        let model = SCNNode()
        bounce.addChildNode(model)

        var legs: [SCNNode] = []
        var wings: [SCNNode] = []
        var head = SCNNode()

        switch kind {
        case .sheep: (head, legs) = buildSheep(in: model, starved: starved)
        case .cow: (head, legs) = buildCow(in: model, starved: starved)
        case .pig: (head, legs) = buildPig(in: model, starved: starved)
        case .chicken: (head, legs, wings) = buildChicken(in: model, starved: starved)
        case .rabbit: (head, legs) = buildRabbit(in: model, starved: starved)
        case .bee: (head, wings) = buildBee(in: model, starved: starved)
        }

        guard !starved else {
            collapse(root: root, model: model, kind: kind)
            return root
        }

        if kind.gait == .fly {
            bounce.position.y = VoxelWorldBuilder.block * 1.3
        }

        animateLegs(legs, gait: kind.gait)
        animateWings(wings, kind: kind)
        animateHead(head, seed: seed)
        animateBounce(bounce, gait: kind.gait, seed: seed)

        if preview {
            let spin = SCNAction.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 6)
            root.runAction(.repeatForever(spin))
        } else {
            wander(root, kind: kind, seed: seed)
        }

        return root
    }

    // MARK: - Models

    private static func buildSheep(in model: SCNNode, starved: Bool) -> (SCNNode, [SCNNode]) {
        let wool = tone(UIColor(white: 0.94, alpha: 1), starved)
        let skin = tone(UIColor(red: 0.85, green: 0.76, blue: 0.72, alpha: 1), starved)

        model.addChildNode(box(10, 9, 15, wool, y: 12.5))
        model.addChildNode(box(11, 4, 13, wool, y: 15.5))

        let neck = pivot(at: SCNVector3(0, 15 * px, 6.5 * px))
        neck.addChildNode(box(6, 6, 6, wool, y: -1, z: 2.6))
        neck.addChildNode(box(5, 5, 2, skin, y: -1, z: 6))
        neck.addChildNode(box(1.4, 1.4, 1, .black, x: -1.6, y: 0.4, z: 6.6))
        neck.addChildNode(box(1.4, 1.4, 1, .black, x: 1.6, y: 0.4, z: 6.6))
        model.addChildNode(neck)

        let legs = fourLegs(in: model, width: 4, height: 8, depth: 4, color: wool, spreadX: 3, spreadZ: 5)
        return (neck, legs)
    }

    private static func buildCow(in model: SCNNode, starved: Bool) -> (SCNNode, [SCNNode]) {
        let hide = tone(UIColor(red: 0.29, green: 0.21, blue: 0.16, alpha: 1), starved)
        let patch = tone(UIColor(white: 0.93, alpha: 1), starved)
        let horn = tone(UIColor(red: 0.85, green: 0.82, blue: 0.7, alpha: 1), starved)
        let udder = tone(UIColor(red: 0.9, green: 0.55, blue: 0.6, alpha: 1), starved)

        model.addChildNode(box(10, 10, 16, hide, y: 14))
        model.addChildNode(box(10.4, 5, 5, patch, x: 0, y: 15, z: -3))
        model.addChildNode(box(10.4, 4, 4, patch, x: 0, y: 11, z: 4))
        model.addChildNode(box(4, 2, 3, udder, y: 8.6, z: -3))

        let neck = pivot(at: SCNVector3(0, 17 * px, 7 * px))
        neck.addChildNode(box(7, 7, 7, hide, z: 3.5))
        neck.addChildNode(box(5, 4, 2, patch, y: -1.4, z: 7.5))
        neck.addChildNode(box(2, 2, 2, horn, x: -3.5, y: 3.5, z: 2))
        neck.addChildNode(box(2, 2, 2, horn, x: 3.5, y: 3.5, z: 2))
        neck.addChildNode(box(1.4, 1.4, 1, .black, x: -2.2, y: 1, z: 7))
        neck.addChildNode(box(1.4, 1.4, 1, .black, x: 2.2, y: 1, z: 7))
        model.addChildNode(neck)

        let legs = fourLegs(in: model, width: 4, height: 9, depth: 4, color: hide, spreadX: 3, spreadZ: 5.5)
        return (neck, legs)
    }

    private static func buildPig(in model: SCNNode, starved: Bool) -> (SCNNode, [SCNNode]) {
        let skin = tone(UIColor(red: 0.94, green: 0.6, blue: 0.62, alpha: 1), starved)
        let snout = tone(UIColor(red: 0.86, green: 0.48, blue: 0.52, alpha: 1), starved)

        model.addChildNode(box(10, 9, 15, skin, y: 12.5))
        model.addChildNode(box(1.6, 1.6, 2.4, snout, y: 15, z: -8))

        let neck = pivot(at: SCNVector3(0, 15 * px, 6.5 * px))
        neck.addChildNode(box(7, 7, 6, skin, z: 3))
        neck.addChildNode(box(4, 3, 1.6, snout, y: -1.2, z: 6.6))
        neck.addChildNode(box(1, 1, 0.6, .black, x: -0.9, y: -1.2, z: 7.2))
        neck.addChildNode(box(1, 1, 0.6, .black, x: 0.9, y: -1.2, z: 7.2))
        neck.addChildNode(box(1.4, 1.4, 1, .black, x: -2.2, y: 1.2, z: 6.2))
        neck.addChildNode(box(1.4, 1.4, 1, .black, x: 2.2, y: 1.2, z: 6.2))
        neck.addChildNode(box(2, 2, 1, snout, x: -2.4, y: 4, z: 2))
        neck.addChildNode(box(2, 2, 1, snout, x: 2.4, y: 4, z: 2))
        model.addChildNode(neck)

        let legs = fourLegs(in: model, width: 4, height: 8, depth: 4, color: snout, spreadX: 3, spreadZ: 5)
        return (neck, legs)
    }

    private static func buildChicken(in model: SCNNode, starved: Bool) -> (SCNNode, [SCNNode], [SCNNode]) {
        let feather = tone(UIColor(white: 0.96, alpha: 1), starved)
        let beak = tone(UIColor(red: 0.95, green: 0.71, blue: 0.19, alpha: 1), starved)
        let comb = tone(UIColor(red: 0.85, green: 0.24, blue: 0.2, alpha: 1), starved)

        model.addChildNode(box(6, 8, 8, feather, y: 9))
        model.addChildNode(box(4, 4, 4, feather, y: 7, z: -5))

        let neck = pivot(at: SCNVector3(0, 12 * px, 2 * px))
        neck.addChildNode(box(4, 6, 3, feather, y: 3, z: 1))
        neck.addChildNode(box(4, 4, 4, feather, y: 6.5, z: 2))
        neck.addChildNode(box(3, 2, 2, beak, y: 6, z: 4.6))
        neck.addChildNode(box(1, 2, 3, comb, y: 9, z: 2))
        neck.addChildNode(box(1.4, 2, 1, comb, y: 4.4, z: 4.4))
        neck.addChildNode(box(1.2, 1.2, 0.8, .black, x: -1.8, y: 7, z: 3.6))
        neck.addChildNode(box(1.2, 1.2, 0.8, .black, x: 1.8, y: 7, z: 3.6))
        model.addChildNode(neck)

        let leftWing = pivot(at: SCNVector3(-3.2 * px, 11 * px, 0))
        leftWing.addChildNode(box(1, 6, 6, feather, x: -0.4))
        let rightWing = pivot(at: SCNVector3(3.2 * px, 11 * px, 0))
        rightWing.addChildNode(box(1, 6, 6, feather, x: 0.4))
        model.addChildNode(leftWing)
        model.addChildNode(rightWing)

        let legs = [
            leg(width: 1.6, height: 5, depth: 1.6, color: beak, x: -1.8, hipY: 5, z: 0),
            leg(width: 1.6, height: 5, depth: 1.6, color: beak, x: 1.8, hipY: 5, z: 0)
        ]
        legs.forEach { model.addChildNode($0) }
        legs.forEach { $0.addChildNode(box(3, 1, 3, beak, y: -5.5, z: 0.8)) }

        return (neck, legs, [leftWing, rightWing])
    }

    private static func buildRabbit(in model: SCNNode, starved: Bool) -> (SCNNode, [SCNNode]) {
        let fur = tone(UIColor(red: 0.62, green: 0.47, blue: 0.34, alpha: 1), starved)
        let belly = tone(UIColor(red: 0.88, green: 0.84, blue: 0.78, alpha: 1), starved)

        model.addChildNode(box(5, 5, 9, fur, y: 6.5, z: -1))
        model.addChildNode(box(2.4, 2.4, 2.4, belly, y: 6, z: -5.6))

        let neck = pivot(at: SCNVector3(0, 8 * px, 3 * px))
        neck.addChildNode(box(5, 5, 5, fur, y: 1, z: 2))
        neck.addChildNode(box(1.6, 5, 1, fur, x: -1.4, y: 5.4, z: 1.4))
        neck.addChildNode(box(1.6, 5, 1, fur, x: 1.4, y: 5.4, z: 1.4))
        neck.addChildNode(box(1.4, 1.4, 0.8, .black, x: -1.8, y: 1.6, z: 4.4))
        neck.addChildNode(box(1.4, 1.4, 0.8, .black, x: 1.8, y: 1.6, z: 4.4))
        neck.addChildNode(box(1.6, 1.2, 1, belly, y: 0, z: 4.8))
        model.addChildNode(neck)

        let legs = [
            leg(width: 2, height: 4, depth: 2, color: fur, x: -1.6, hipY: 4, z: 3),
            leg(width: 2, height: 4, depth: 2, color: fur, x: 1.6, hipY: 4, z: 3),
            leg(width: 2.4, height: 4, depth: 5, color: fur, x: -1.6, hipY: 4.4, z: -4),
            leg(width: 2.4, height: 4, depth: 5, color: fur, x: 1.6, hipY: 4.4, z: -4)
        ]
        legs.forEach { model.addChildNode($0) }
        return (neck, legs)
    }

    private static func buildBee(in model: SCNNode, starved: Bool) -> (SCNNode, [SCNNode]) {
        let amber = tone(UIColor(red: 0.94, green: 0.72, blue: 0.19, alpha: 1), starved)
        let dark = tone(UIColor(red: 0.24, green: 0.19, blue: 0.14, alpha: 1), starved)

        model.addChildNode(box(7, 7, 10, amber, y: 7))
        model.addChildNode(box(7.3, 7.3, 2, dark, y: 7, z: -1.5))
        model.addChildNode(box(7.3, 7.3, 2, dark, y: 7, z: -4.5))
        model.addChildNode(box(1, 1, 2, dark, y: 7, z: -6.4))

        let neck = pivot(at: SCNVector3(0, 7 * px, 5 * px))
        neck.addChildNode(box(1.4, 1.4, 0.8, .black, x: -2, y: 1, z: 0.4))
        neck.addChildNode(box(1.4, 1.4, 0.8, .black, x: 2, y: 1, z: 0.4))
        neck.addChildNode(box(1, 3, 1, dark, x: -1.6, y: 4.4, z: -0.6))
        neck.addChildNode(box(1, 3, 1, dark, x: 1.6, y: 4.4, z: -0.6))
        model.addChildNode(neck)

        let wingColor = UIColor(white: 0.95, alpha: 1)
        let leftWing = pivot(at: SCNVector3(-2 * px, 11 * px, 0))
        leftWing.addChildNode(box(6, 0.6, 5, wingColor, x: -3.4, transparent: true))
        let rightWing = pivot(at: SCNVector3(2 * px, 11 * px, 0))
        rightWing.addChildNode(box(6, 0.6, 5, wingColor, x: 3.4, transparent: true))
        model.addChildNode(leftWing)
        model.addChildNode(rightWing)

        return (neck, [leftWing, rightWing])
    }

    // MARK: - Geometry helpers

    /// Parts repeat a lot across the herd, so identical boxes share one geometry.
    private static var geometryCache: [String: SCNGeometry] = [:]

    private static func box(
        _ width: Float,
        _ height: Float,
        _ depth: Float,
        _ color: UIColor,
        x: Float = 0,
        y: Float = 0,
        z: Float = 0,
        transparent: Bool = false
    ) -> SCNNode {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let key = "\(width)|\(height)|\(depth)|\(red)|\(green)|\(blue)|\(alpha)|\(transparent)"

        let geometry: SCNGeometry
        if let cached = geometryCache[key] {
            geometry = cached
        } else {
            let box = SCNBox(
                width: CGFloat(width * px),
                height: CGFloat(height * px),
                length: CGFloat(depth * px),
                chamferRadius: 0
            )
            box.firstMaterial = material(color, transparent: transparent)
            geometryCache[key] = box
            geometry = box
        }

        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(x * px, y * px, z * px)
        return node
    }

    private static func pivot(at position: SCNVector3) -> SCNNode {
        let node = SCNNode()
        node.position = position
        return node
    }

    private static func leg(
        width: Float,
        height: Float,
        depth: Float,
        color: UIColor,
        x: Float,
        hipY: Float,
        z: Float
    ) -> SCNNode {
        let hip = pivot(at: SCNVector3(x * px, hipY * px, z * px))
        hip.addChildNode(box(width, height, depth, color, y: -height / 2))
        return hip
    }

    private static func fourLegs(
        in model: SCNNode,
        width: Float,
        height: Float,
        depth: Float,
        color: UIColor,
        spreadX: Float,
        spreadZ: Float
    ) -> [SCNNode] {
        let legs = [
            leg(width: width, height: height, depth: depth, color: color, x: -spreadX, hipY: height, z: spreadZ),
            leg(width: width, height: height, depth: depth, color: color, x: spreadX, hipY: height, z: spreadZ),
            leg(width: width, height: height, depth: depth, color: color, x: -spreadX, hipY: height, z: -spreadZ),
            leg(width: width, height: height, depth: depth, color: color, x: spreadX, hipY: height, z: -spreadZ)
        ]
        legs.forEach { model.addChildNode($0) }
        return legs
    }

    private static func material(_ color: UIColor, transparent: Bool) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .lambert
        material.diffuse.contents = color
        material.roughness.contents = 1
        material.metalness.contents = 0
        if transparent {
            material.transparency = 0.55
            material.isDoubleSided = true
        }
        return material
    }

    private static func tone(_ color: UIColor, _ starved: Bool) -> UIColor {
        guard starved else { return color }
        var white: CGFloat = 0, alpha: CGFloat = 0
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        color.getWhite(&white, alpha: &alpha)
        return UIColor(hue: hue, saturation: saturation * 0.15, brightness: brightness * 0.55, alpha: alpha)
    }

    // MARK: - Animation

    private static func animateLegs(_ legs: [SCNNode], gait: VoxelAnimalGait) {
        guard gait != .fly, !legs.isEmpty else { return }
        let amplitude = gait == .hop ? 0.34 : 0.5
        let period = gait == .hop ? 0.34 : 0.5

        for (index, leg) in legs.enumerated() {
            let leading = index == 0 || index == 3
            leg.eulerAngles.x = Float(leading ? -amplitude / 2 : amplitude / 2)
            let forward = SCNAction.rotateBy(x: CGFloat(amplitude), y: 0, z: 0, duration: period)
            forward.timingMode = .easeInEaseOut
            let backward = forward.reversed()
            let cycle = leading
                ? SCNAction.sequence([forward, backward])
                : SCNAction.sequence([backward, forward])
            leg.runAction(.repeatForever(cycle))
        }
    }

    private static func animateWings(_ wings: [SCNNode], kind: VoxelAnimalKind) {
        guard !wings.isEmpty else { return }
        let amplitude: CGFloat = kind == .bee ? 0.75 : 0.35
        let period = kind == .bee ? 0.07 : 0.9

        for (index, wing) in wings.enumerated() {
            let sign: CGFloat = index == 0 ? 1 : -1
            let up = SCNAction.rotateBy(x: 0, y: 0, z: amplitude * sign, duration: period)
            up.timingMode = .easeInEaseOut
            wing.runAction(.repeatForever(.sequence([up, up.reversed()])))
        }
    }

    private static func animateHead(_ head: SCNNode, seed: Int) {
        var random = VoxelRandom(seed: UInt64(truncatingIfNeeded: seed &* 31 &+ 7))
        let graze = SCNAction.rotateBy(x: 0.55, y: 0, z: 0, duration: 0.45)
        graze.timingMode = .easeInEaseOut
        let look = SCNAction.rotateBy(x: 0, y: 0.4, z: 0, duration: 0.5)
        look.timingMode = .easeInEaseOut

        let routine = SCNAction.sequence([
            SCNAction.wait(duration: Double.random(in: 1.5...4, using: &random)),
            graze,
            SCNAction.wait(duration: Double.random(in: 0.8...2.2, using: &random)),
            graze.reversed(),
            SCNAction.wait(duration: Double.random(in: 1...3, using: &random)),
            look,
            look.reversed()
        ])
        head.runAction(.repeatForever(routine))
    }

    private static func animateBounce(_ bounce: SCNNode, gait: VoxelAnimalGait, seed: Int) {
        switch gait {
        case .walk:
            let rise = SCNAction.moveBy(x: 0, y: CGFloat(px * 0.7), z: 0, duration: 0.5)
            rise.timingMode = .easeInEaseOut
            bounce.runAction(.repeatForever(.sequence([rise, rise.reversed()])))
        case .hop:
            let up = SCNAction.moveBy(x: 0, y: CGFloat(px * 3), z: 0, duration: 0.17)
            up.timingMode = .easeOut
            let down = up.reversed()
            down.timingMode = .easeIn
            bounce.runAction(.repeatForever(.sequence([up, down])))
        case .fly:
            var random = VoxelRandom(seed: UInt64(truncatingIfNeeded: seed &* 17 &+ 3))
            let drift = SCNAction.moveBy(x: 0, y: CGFloat(px * 2.4), z: 0, duration: Double.random(in: 0.9...1.4, using: &random))
            drift.timingMode = .easeInEaseOut
            bounce.runAction(.repeatForever(.sequence([drift, drift.reversed()])))
        }
    }

    private static func wander(_ root: SCNNode, kind: VoxelAnimalKind, seed: Int) {
        var random = VoxelRandom(seed: UInt64(truncatingIfNeeded: seed &* 7919 &+ 13))
        let radius = VoxelWorldBuilder.block * (kind.gait == .fly ? 1.6 : 1.1)
        var current = SCNVector3Zero
        var steps: [SCNAction] = []

        for _ in 0..<4 {
            let angle = Float.random(in: 0..<(2 * .pi), using: &random)
            let distance = Float.random(in: (radius * 0.35)...radius, using: &random)
            let target = SCNVector3(cosf(angle) * distance, 0, sinf(angle) * distance)
            let dx = target.x - current.x
            let dz = target.z - current.z
            let length = max(0.01, sqrtf(dx * dx + dz * dz))

            let turn = SCNAction.rotateTo(
                x: 0,
                y: CGFloat(atan2f(dx, dz)),
                z: 0,
                duration: 0.4,
                usesShortestUnitArc: true
            )
            let move = SCNAction.move(to: target, duration: Double(length / kind.speed))
            move.timingMode = .easeInEaseOut

            steps.append(turn)
            steps.append(move)
            steps.append(.wait(duration: Double.random(in: 0.4...2.4, using: &random)))
            current = target
        }

        root.runAction(.repeatForever(.sequence(steps)))
    }

    private static func collapse(root: SCNNode, model: SCNNode, kind: VoxelAnimalKind) {
        model.eulerAngles.z = Float.pi / 2
        model.position.y = px * (kind == .cow ? 5 : 4)

        let breathe = SCNAction.rotateBy(x: 0, y: 0, z: 0.05, duration: 2.4)
        breathe.timingMode = .easeInEaseOut
        model.runAction(.repeatForever(.sequence([breathe, breathe.reversed()])))
        root.opacity = 0.85
    }
}