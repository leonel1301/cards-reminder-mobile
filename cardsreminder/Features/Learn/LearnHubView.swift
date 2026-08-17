import SwiftUI

struct LearnHubView: View {
    var showsCloseButton: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(LearnAPIService.self) private var learnService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(LearnTrack.allCases) { track in
                    NavigationLink(value: track) {
                        LearnTrackCard(
                            track: track,
                            completed: learnService.completedCount(in: track),
                            total: LearnCatalog.lessons(in: track).count
                        )
                    }
                    .buttonStyle(.plain)
                }

                NavigationLink(value: ContractRoute()) {
                    contractCard
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
            .animation(SmoothRevealAnimation.motion, value: learnService.contentRevision)
        }
        .background(Color.appBackground)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle("screen_learn_title")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await learnService.fetchProgress()
        }
        .toolbar {
            if showsCloseButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("action_done") { dismiss() }
                }
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("learn_hub_subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }

    private var contractCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.viewfinder")
                .font(.title2)
                .foregroundStyle(Color.primaryAction)
                .frame(width: 44, height: 44)
                .background(Color.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text("contract_title")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("contract_powered")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.primaryAction)

                Text("contract_card_subtitle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.defaultBorder, lineWidth: 1)
        }
    }
}

private struct LearnTrackCard: View {
    let track: LearnTrack
    let completed: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: track.iconName)
                .font(.title2)
                .foregroundStyle(track == .banks ? Color.violetStateForeground : Color.primaryAction)
                .frame(width: 44, height: 44)
                .background(Color.cardSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(LocalizedStringKey(track.titleKey))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(LocalizedStringKey(track.subtitleKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                ProgressView(value: progress)
                    .tint(Color.primaryAction)

                Text("\(completed)/\(total)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.defaultBorder, lineWidth: 1)
        }
    }
}

#Preview {
    NavigationStack {
        LearnHubView()
    }
    .environment(LearnAPIService())
}
