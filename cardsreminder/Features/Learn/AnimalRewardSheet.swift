import SceneKit
import SwiftUI

struct LessonAnimalReward: Identifiable, Equatable {
    let id = UUID()
    let kind: VoxelAnimalKind
    let track: LearnTrack

    static func unlocked(for track: LearnTrack) -> LessonAnimalReward? {
        guard let index = LearnTrack.allCases.firstIndex(of: track) else { return nil }
        return LessonAnimalReward(
            kind: .reward(forCompletedIndex: index),
            track: track
        )
    }
}

struct AnimalRewardSheet: View {
    let reward: LessonAnimalReward
    var onClaim: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        animalStage
                            .padding(.top, 8)

                        VStack(spacing: 8) {
                            Text("learn_animal_reward_title")
                                .font(.title2.bold())
                                .multilineTextAlignment(.center)

                            Text(LocalizedStringKey(reward.kind.titleKey))
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color.primaryAction)

                            Text(LocalizedStringKey(reward.track.titleKey))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)

                            Text("learn_animal_reward_subtitle")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)

                Button {
                    Haptics.mediumImpact()
                    onClaim()
                } label: {
                    Text("learn_animal_reward_claim")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.primaryAction)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color.appBackground)
            .navigationTitle("learn_animal_reward_nav_title")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.7, dampingFraction: 0.78)) {
                appeared = true
            }
        }
    }

    private var animalStage: some View {
        ZStack {
            Circle()
                .fill(Color.primaryAction.opacity(0.12))
                .frame(width: 168, height: 168)
                .scaleEffect(appeared ? 1 : 0.82)
                .opacity(appeared ? 1 : 0)

            Circle()
                .strokeBorder(Color.primaryAction.opacity(0.18), lineWidth: 1)
                .frame(width: 188, height: 188)

            AnimalPreviewSceneView(kind: reward.kind, isActive: true)
                .frame(width: 200, height: 200)
                .scaleEffect(appeared ? 1 : 0.7)
                .opacity(appeared ? 1 : 0)
        }
        .frame(height: 220)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(reward.kind.titleKey)))
    }
}

private struct AnimalPreviewSceneView: UIViewRepresentable {
    var kind: VoxelAnimalKind
    var isActive: Bool

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.isPlaying = isActive
        view.rendersContinuously = isActive
        view.scene = Self.makeScene(kind: kind)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.isPlaying = isActive
        uiView.rendersContinuously = isActive
        if context.coordinator.kind != kind {
            uiView.scene = Self.makeScene(kind: kind)
            context.coordinator.kind = kind
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(kind: kind)
    }

    final class Coordinator {
        var kind: VoxelAnimalKind
        init(kind: VoxelAnimalKind) { self.kind = kind }
    }

    private static func makeScene(kind: VoxelAnimalKind) -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let ambient = SCNNode()
        ambient.light = {
            let light = SCNLight()
            light.type = .ambient
            light.intensity = 420
            light.color = UIColor.white
            return light
        }()
        scene.rootNode.addChildNode(ambient)

        let key = SCNNode()
        key.light = {
            let light = SCNLight()
            light.type = .directional
            light.intensity = 900
            light.castsShadow = false
            light.color = UIColor.white
            return light
        }()
        key.eulerAngles = SCNVector3(-0.7, 0.55, 0)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = {
            let light = SCNLight()
            light.type = .directional
            light.intensity = 320
            light.color = UIColor(white: 0.95, alpha: 1)
            return light
        }()
        fill.eulerAngles = SCNVector3(-0.2, -1.1, 0.2)
        scene.rootNode.addChildNode(fill)

        let animal = VoxelAnimalBuilder.make(
            kind: kind,
            starved: false,
            seed: kind.rawValue * 17 + 3,
            preview: true
        )
        animal.position = SCNVector3(0, -0.05, 0)
        scene.rootNode.addChildNode(animal)

        let camera = SCNNode()
        camera.camera = {
            let cam = SCNCamera()
            cam.fieldOfView = 38
            cam.zNear = 0.01
            cam.zFar = 20
            return cam
        }()
        camera.position = SCNVector3(0.55, 0.72, 1.35)
        camera.look(at: SCNVector3(0, 0.18, 0))
        scene.rootNode.addChildNode(camera)

        return scene
    }
}

#Preview {
    AnimalRewardSheet(reward: .unlocked(for: .basics)!, onClaim: {})
}
