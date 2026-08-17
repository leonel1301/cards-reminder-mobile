import SwiftUI
import UIKit

struct GardenShareCard: View {
    let worldImage: UIImage
    let snapshot: VoxelWorldSnapshot
    let colorScheme: ColorScheme

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                LinearGradient(
                    colors: [
                        snapshot.health.skyTopColor(for: colorScheme),
                        snapshot.health.skyBottomColor(for: colorScheme)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Image(uiImage: worldImage)
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 20)
                    .padding(.top, 36)
                    .padding(.bottom, 8)
            }
            .frame(height: 430)

            VStack(alignment: .leading, spacing: 8) {
                Text("garden_share_brand")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.primaryAction)
                    .textCase(.uppercase)

                Text(LocalizedStringKey(snapshot.health.titleKey))
                    .font(.title2.bold())

                Text(statsLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(LocalizedStringKey(snapshot.health.subtitleKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
        }
        .frame(width: 360)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .environment(\.colorScheme, colorScheme)
    }

    private var statsLine: String {
        String(
            format: String(localized: "things_world_stats"),
            snapshot.livingAnimalCount
        )
    }
}

enum GardenShareComposer {
    @MainActor
    static func compose(
        snapshot: VoxelWorldSnapshot,
        seed: Int,
        colorScheme: ColorScheme
    ) -> (image: UIImage, message: String)? {
        let world = VoxelWorldBuilder.snapshotImage(snapshot: snapshot, seed: seed, isDark: colorScheme == .dark)
        let card = GardenShareCard(worldImage: world, snapshot: snapshot, colorScheme: colorScheme)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3
        renderer.proposedSize = ProposedViewSize(width: 360, height: nil)

        guard let image = renderer.uiImage else { return nil }

        let stats = String(
            format: String(localized: "things_world_stats"),
            snapshot.livingAnimalCount
        )
        let title = String(localized: String.LocalizationValue(snapshot.health.titleKey))
        let message = String(format: String(localized: "garden_share_message"), title, stats)

        return (image, message)
    }
}
