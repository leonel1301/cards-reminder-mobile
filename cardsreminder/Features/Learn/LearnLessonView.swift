import SwiftUI

struct LearnLessonView: View {
    let lesson: LearnLesson

    @Environment(LearnAPIService.self) private var learnService
    @State private var isSaving = false
    @State private var animalReward: LessonAnimalReward?

    private var isCompleted: Bool {
        learnService.isCompleted(lesson.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: lesson.iconName)
                        .font(.title2)
                        .foregroundStyle(Color.primaryAction)
                        .frame(width: 48, height: 48)
                        .background(Color.primaryAction.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    Text(LocalizedStringKey(lesson.summaryKey))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text(LocalizedStringKey(lesson.bodyKey))
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    guard !isSaving else { return }
                    isSaving = true
                    Task {
                        await handleToggle()
                        isSaving = false
                    }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(isCompleted ? Color.emeraldStateForeground : .white)
                        } else {
                            Label(
                                isCompleted ? "learn_mark_unread" : "learn_mark_read",
                                systemImage: isCompleted ? "checkmark.circle.fill" : "circle"
                            )
                        }
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .foregroundStyle(isCompleted ? Color.emeraldStateForeground : .white)
                    .background(isCompleted ? Color.emeraldStateBackground : Color.primaryAction)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isSaving)
                .padding(.top, 8)

                if let errorMessage = learnService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color.redStateForeground)
                }
            }
            .padding(20)
            .animation(SmoothRevealAnimation.motion, value: learnService.contentRevision)
        }
        .background(Color.appBackground)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle(LocalizedStringKey(lesson.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $animalReward) { reward in
            AnimalRewardSheet(reward: reward) {
                animalReward = nil
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func handleToggle() async {
        if isCompleted {
            _ = await learnService.unmarkCompleted(lesson.id)
            return
        }

        let tracksBefore = Set(learnService.completedTracks)
        let didMark = await learnService.markCompleted(lesson.id)
        guard didMark else { return }

        if let newlyCompleted = learnService.completedTracks.first(where: { !tracksBefore.contains($0) }),
           let reward = LessonAnimalReward.unlocked(for: newlyCompleted) {
            animalReward = reward
        }
    }
}
