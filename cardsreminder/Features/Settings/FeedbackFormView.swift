import SwiftUI

struct FeedbackFormView: View {
    enum Mode {
        case create
        case edit(APIFeedback)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(FeedbackAPIService.self) private var feedbackService

    let mode: Mode

    @State private var title = ""
    @State private var content = ""
    @State private var showDeleteConfirmation = false
    @State private var isSubmitting = false

    private var editingFeedbackID: UUID? {
        if case .edit(let feedback) = mode { return feedback.id }
        return nil
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var navigationTitle: LocalizedStringKey {
        isEditing ? "screen_edit_feedback_title" : "screen_new_feedback_title"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("section_feedback") {
                    TextField("field_feedback_title", text: $title)
                }

                Section("field_feedback_content") {
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                }

                Section("field_device") {
                    Text(DeviceInfo.feedbackDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if isEditing {
                    Section {
                        Button("action_delete_feedback", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }

                if let errorMessage = feedbackService.errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action_cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("action_save") {
                        Task { await save() }
                    }
                    .disabled(!canSave || isSubmitting)
                }
            }
            .task(id: editingFeedbackID) {
                loadExistingValues()
            }
            .alert("delete_feedback_confirm_title", isPresented: $showDeleteConfirmation) {
                Button("action_cancel", role: .cancel) {}
                Button("action_delete", role: .destructive) {
                    Task { await deleteFeedback() }
                }
            }
            .overlay {
                if isSubmitting {
                    ProgressView()
                }
            }
        }
    }

    private var canSave: Bool {
        !trimmedTitle.isEmpty && !trimmedContent.isEmpty
    }

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedContent: String {
        content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func loadExistingValues() {
        switch mode {
        case .create:
            title = ""
            content = ""
        case .edit(let feedback):
            title = feedback.title
            content = feedback.content
        }
    }

    private func save() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let device = DeviceInfo.feedbackDescription

        switch mode {
        case .create:
            let request = CreateFeedbackRequest(
                title: trimmedTitle,
                device: device,
                content: trimmedContent
            )
            if await feedbackService.createFeedback(request) != nil {
                dismiss()
            }

        case .edit(let feedback):
            let request = UpdateFeedbackRequest(
                title: trimmedTitle,
                device: device,
                content: trimmedContent
            )
            if await feedbackService.updateFeedback(id: feedback.id, request) != nil {
                dismiss()
            }
        }
    }

    private func deleteFeedback() async {
        guard case .edit(let feedback) = mode else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        if await feedbackService.deleteFeedback(id: feedback.id) {
            dismiss()
        }
    }
}

#Preview {
    FeedbackFormView(mode: .create)
        .environment(FeedbackAPIService())
}
