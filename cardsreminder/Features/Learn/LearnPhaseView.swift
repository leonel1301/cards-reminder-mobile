import SwiftUI

struct LearnPhaseView: View {
    let track: LearnTrack

    @Environment(LearnAPIService.self) private var learnService

    private var lessons: [LearnLesson] {
        LearnCatalog.lessons(in: track)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(LocalizedStringKey(track.subtitleKey))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)

                VStack(spacing: 10) {
                    ForEach(lessons) { lesson in
                        NavigationLink(value: lesson) {
                            LearnLessonRow(
                                lesson: lesson,
                                isCompleted: learnService.isCompleted(lesson.id)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
            .animation(SmoothRevealAnimation.motion, value: learnService.contentRevision)
        }
        .background(Color.appBackground)
        .toolbarBackground(Color.appBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle(LocalizedStringKey(track.titleKey))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await learnService.fetchProgress()
        }
    }
}

private struct LearnLessonRow: View {
    let lesson: LearnLesson
    let isCompleted: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.primaryAction.opacity(0.12))
                    .frame(width: 44, height: 44)

                Image(systemName: lesson.iconName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primaryAction)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(lesson.titleKey))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(LocalizedStringKey(lesson.summaryKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.emeraldStateForeground)
            }

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
