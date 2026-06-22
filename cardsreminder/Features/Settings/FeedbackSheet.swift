import SwiftUI

private enum FeedbackSheetRoute: Identifiable {
    case create
    case edit(APIFeedback)

    var id: String {
        switch self {
        case .create:
            "create"
        case .edit(let feedback):
            feedback.id.uuidString
        }
    }
}

struct FeedbackSheet: View {
    @Environment(\.openURL) private var openURL
    @Environment(FeedbackAPIService.self) private var feedbackService

    @State private var activeForm: FeedbackSheetRoute?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerIcon

                    if feedbackService.isLoading && feedbackService.feedbacks.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 32)
                    } else if feedbackService.feedbacks.isEmpty {
                        emptyState
                    } else {
                        feedbackList
                    }

                    if let errorMessage = feedbackService.errorMessage {
                        errorBanner(errorMessage)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
                .animation(SmoothRevealAnimation.motion, value: feedbackService.contentRevision)
            }
            .scrollBounceBehavior(.basedOnSize, axes: .vertical)
            .navigationTitle("feedback_sheet_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activeForm = .create
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel(Text("action_add_feedback"))
                }
            }
            .refreshable {
                await feedbackService.fetchFeedbacks()
            }
        }
        .task {
            await feedbackService.fetchFeedbacks()
        }
        .sheet(item: $activeForm) { route in
            switch route {
            case .create:
                FeedbackFormView(mode: .create)
            case .edit(let feedback):
                FeedbackFormView(mode: .edit(feedback))
                    .id(feedback.id)
            }
        }
    }

    private var headerIcon: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 72, height: 72)
                .background(Color.accentColor.opacity(0.14))
                .clipShape(Circle())
                .padding(.top, 8)

            Button {
                openURL(AppMetadata.feedbackURL)
            } label: {
                HStack(spacing: 4) {
                    Text("feedback_more_link")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)

                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("feedback_more_link"))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("feedback_empty_title")
                .font(.headline)

            Text("feedback_empty_message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var feedbackList: some View {
        VStack(spacing: 0) {
            ForEach(Array(feedbackService.feedbacks.enumerated()), id: \.element.id) { index, feedback in
                Button {
                    activeForm = .edit(feedback)
                } label: {
                    feedbackRow(feedback)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .transition(SmoothRevealAnimation.transition)
                .animation(
                    SmoothRevealAnimation.motion.delay(SmoothRevealAnimation.staggerDelay(for: index)),
                    value: feedbackService.contentRevision
                )

                if feedback.id != feedbackService.feedbacks.last?.id {
                    Divider()
                }
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func feedbackRow(_ feedback: APIFeedback) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(feedback.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)

                Text(feedback.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(feedback.updatedAt.formatted(.dateTime.day().month(.abbreviated).year()))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
        }
        .padding(16)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    FeedbackSheet()
        .environment(FeedbackAPIService())
        .presentationDetents([.medium, .large])
}
