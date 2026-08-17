import SwiftUI

struct GardenView: View {
    @Environment(PaymentsAPIService.self) private var paymentsService
    @Environment(LearnAPIService.self) private var learnService
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("garden.worldSeed") private var worldSeed = 0
    @State private var isSharing = false
    @State private var sharePayload: ActivitySharePayload?
    @State private var shareFailed = false

    private var snapshot: VoxelWorldSnapshot {
        VoxelWorldSnapshot(
            summary: paymentsService.summary,
            unlockedAnimals: learnService.unlockedAnimalKinds,
            paymentCount: paymentsService.paymentCount
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    worldHero
                    learnSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color.appBackground)
            .navigationTitle("screen_garden_title")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.automatic, for: .navigationBar)
            .task {
                async let dashboard: Void = paymentsService.fetchDashboard()
                async let payments: Void = paymentsService.fetchPaymentCount()
                async let lessons: Void = learnService.fetchProgress()
                _ = await (dashboard, payments, lessons)
            }
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        rebuildWorld()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityLabel(Text("garden_rebuild_action"))
                    .accessibilityHint(Text("garden_rebuild_hint"))

                    Button {
                        Task { await shareWorld() }
                    } label: {
                        if isSharing {
                            ProgressView()
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    .disabled(isSharing)
                    .accessibilityLabel(Text("garden_share_action"))
                }
            }
            .navigationDestination(for: LearnTrack.self) { track in
                LearnPhaseView(track: track)
            }
            .navigationDestination(for: LearnLesson.self) { lesson in
                LearnLessonView(lesson: lesson)
            }
            .navigationDestination(for: ContractRoute.self) { _ in
                ContractAnalyzeView()
            }
            .activityShareSheet(payload: $sharePayload)
            .alert("garden_share_failed_title", isPresented: $shareFailed) {
                Button("action_cancel", role: .cancel) {}
            } message: {
                Text("garden_share_failed_message")
            }
        }
    }

    private func shareWorld() async {
        guard !isSharing else { return }
        isSharing = true
        defer { isSharing = false }

        guard let composed = GardenShareComposer.compose(
            snapshot: snapshot,
            seed: worldSeed,
            colorScheme: colorScheme
        ) else {
            shareFailed = true
            return
        }

        Haptics.lightImpact()
        sharePayload = ActivitySharePayload(items: [composed.image, composed.message])
    }

    private func rebuildWorld() {
        Haptics.mediumImpact()
        worldSeed = VoxelWorldRecipe.nextSeed(after: worldSeed)
    }

    private var worldHero: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [
                    snapshot.health.skyTopColor(for: colorScheme),
                    snapshot.health.skyBottomColor(for: colorScheme)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            WorldSceneView(
                snapshot: snapshot,
                seed: worldSeed,
                isDark: colorScheme == .dark,
                allowsCameraControl: true,
                isActive: navigation.selectedTab == .garden
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(snapshot.health.titleKey))
                    .font(.headline)

                Text(worldStats)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if snapshot.starvedAnimalCount > 0 {
                    Text(starvedLine)
                        .font(.caption)
                        .foregroundStyle(Color.redStateForeground)
                }

                Text("garden_tree_hint")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
        }
        .frame(height: 460)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(alignment: .topTrailing) {
            WorldCloudView(
                snapshot: snapshot,
                isActive: navigation.selectedTab == .garden
            )
        }
    }

    private var worldStats: String {
        String(
            format: String(localized: "things_world_stats"),
            snapshot.livingAnimalCount
        )
    }

    private var starvedLine: String {
        String(
            format: String(localized: "things_world_starved"),
            snapshot.starvedAnimalCount
        )
    }

    private var learnSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("screen_learn_title")
                    .font(.title2.bold())

                Text("learn_hub_subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            NavigationLink(value: ContractRoute()) {
                contractRow
            }
            .buttonStyle(.plain)

            VStack(spacing: 10) {
                ForEach(LearnTrack.allCases) { track in
                    NavigationLink(value: track) {
                        learnRow(for: track)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var contractRow: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.primaryAction.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: "doc.viewfinder")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primaryAction)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("contract_title")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("contract_powered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.primaryAction)

                Text("contract_card_subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func learnRow(for track: LearnTrack) -> some View {
        let completed = learnService.completedCount(in: track)
        let total = LearnCatalog.lessons(in: track).count
        let progress = total == 0 ? 0 : Double(completed) / Double(total)

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.primaryAction.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: track.iconName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primaryAction)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(track.titleKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(LocalizedStringKey(track.subtitleKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                ProgressView(value: progress)
                    .tint(Color.primaryAction)
            }

            Text("\(completed)/\(total)")
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ContractRoute: Hashable {}

#Preview {
    GardenView()
        .environment(PaymentsAPIService())
        .environment(LearnAPIService())
        .environment(AppNavigation())
}
