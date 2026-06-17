import SwiftUI

struct OwnerFormView: View {
    enum Mode {
        case create
        case edit(APIOwner)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(OwnersAPIService.self) private var ownersService

    let mode: Mode

    @State private var name = ""
    @State private var salaryDaySelection = 0
    @State private var showDeleteConfirmation = false
    @State private var isSubmitting = false

    private var editingOwnerID: UUID? {
        if case .edit(let owner) = mode { return owner.id }
        return nil
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var editingOwner: APIOwner? {
        if case .edit(let owner) = mode { return owner }
        return nil
    }

    private var isSelfOwner: Bool {
        editingOwner?.isSelf == true
    }

    private var navigationTitle: LocalizedStringKey {
        switch mode {
        case .create:
            return "screen_new_owner_title"
        case .edit(let owner) where owner.isSelf:
            return "screen_edit_self_salary_title"
        case .edit:
            return "screen_edit_owner_title"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if !isSelfOwner {
                    Section("section_owner") {
                        TextField("field_owner_name", text: $name)
                    }
                } else if let owner = editingOwner {
                    Section("section_owner") {
                        LabeledContent("field_owner_name", value: owner.name)
                    }
                }

                Section("section_salary_day") {
                    SalaryDayPicker(selection: $salaryDaySelection)
                }

                if isEditing, let owner = editingOwner, !owner.isSelf {
                    Section {
                        Button("action_delete_owner", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }

                if let errorMessage = ownersService.errorMessage {
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
            .task(id: editingOwnerID) {
                loadExistingValues()
            }
            .confirmationDialog(
                "delete_owner_confirm_title",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("action_delete", role: .destructive) {
                    Task { await deleteOwner() }
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
        if isSelfOwner { return true }
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var salaryDayValue: Int? {
        salaryDaySelection == 0 ? nil : salaryDaySelection
    }

    private func loadExistingValues() {
        switch mode {
        case .create:
            name = ""
            salaryDaySelection = 0
        case .edit(let owner):
            name = owner.name
            salaryDaySelection = owner.salaryDay ?? 0
        }
    }

    private func save() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .create:
            let request = CreateOwnerRequest(name: trimmedName, salaryDay: salaryDayValue)
            if await ownersService.createOwner(request) != nil {
                dismiss()
            }

        case .edit(let owner):
            let request = UpdateOwnerRequest(
                name: isSelfOwner ? nil : trimmedName,
                salaryDay: salaryDayValue
            )
            if await ownersService.updateOwner(id: owner.id, request) != nil {
                dismiss()
            }
        }
    }

    private func deleteOwner() async {
        guard case .edit(let owner) = mode, !owner.isSelf else { return }

        isSubmitting = true
        defer { isSubmitting = false }

        if await ownersService.deleteOwner(id: owner.id) {
            dismiss()
        }
    }
}

struct SalaryDayPicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("field_salary_day", selection: $selection) {
            Text("salary_day_not_set").tag(0)
            ForEach(1...31, id: \.self) { day in
                Text(
                    String(format: String(localized: "owner_salary_day_value"), day)
                )
                .tag(day)
            }
        }
        .pickerStyle(.menu)
    }
}

#Preview {
    OwnerFormView(mode: .create)
        .environment(OwnersAPIService())
}
