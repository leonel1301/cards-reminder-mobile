import SwiftUI

struct CardFormView: View {
    enum Mode {
        case create
        case edit(APICard)
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(CardsAPIService.self) private var cardsService
    @Environment(OwnersAPIService.self) private var ownersService

    let mode: Mode

    @State private var name = ""
    @State private var lastFourDigits = ""
    @State private var issuer = ""
    @State private var billingCycleDay = 1
    @State private var paymentDueDay = 1
    @State private var selectedColorHex = CardPaletteOption.defaultHex
    @State private var notes = ""
    @State private var isActive = true
    @State private var selectedOwnerID: UUID?
    @State private var showDeleteConfirmation = false
    @State private var expandedDayPickerID: String?

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var navigationTitle: LocalizedStringKey {
        isEditing ? "screen_edit_card_title" : "screen_new_card_title"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("section_card") {
                    TextField("field_card_name", text: $name)
                    TextField("field_last_four_digits", text: $lastFourDigits)
                        .keyboardType(.numberPad)
                    TextField("field_issuer_optional", text: $issuer)
                }

                Section("section_billing") {
                    DayNumberPicker(
                        id: "billing_cycle",
                        title: String(localized: "picker_billing_cycle_day"),
                        selection: $billingCycleDay,
                        expandedPickerID: $expandedDayPickerID
                    )

                    Text(
                        String(
                            format: String(localized: "period_start_preview"),
                            periodStartPreview
                        )
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    DayNumberPicker(
                        id: "payment_due",
                        title: String(localized: "picker_payment_due_day"),
                        selection: $paymentDueDay,
                        expandedPickerID: $expandedDayPickerID
                    )
                }

                Section("section_owner") {
                    if isEditing {
                        Picker("field_card_owner", selection: $selectedOwnerID) {
                            ForEach(ownersService.owners) { owner in
                                Text(owner.displayName).tag(Optional(owner.id))
                            }
                        }
                    } else {
                        Picker("field_card_owner", selection: $selectedOwnerID) {
                            Text("owner_auto_assign").tag(Optional<UUID>.none)
                            ForEach(ownersService.owners) { owner in
                                Text(owner.displayName).tag(Optional(owner.id))
                            }
                        }
                    }
                }

                Section("section_appearance") {
                    CardColorPaletteGrid(selection: $selectedColorHex)
                }

                Section("section_notes") {
                    TextField("field_notes_optional", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }

                if isEditing {
                    Section {
                        Toggle("field_card_active", isOn: $isActive)
                    }

                    Section {
                        Button("action_delete_card", role: .destructive) {
                            showDeleteConfirmation = true
                        }
                    }
                }

                if let errorMessage = cardsService.errorMessage {
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
                    .disabled(!canSave || cardsService.isLoading)
                }
            }
            .task {
                await ownersService.fetchOwners()
            }
            .onAppear(perform: loadExistingValues)
            .confirmationDialog(
                "delete_card_confirm_title",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("action_delete", role: .destructive) {
                    Task { await deleteCard() }
                }
            }
            .overlay {
                if cardsService.isLoading {
                    ProgressView()
                }
            }
        }
    }

    private var periodStartPreview: Int {
        billingCycleDay >= 31 ? 1 : billingCycleDay + 1
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && lastFourDigits.count == 4
            && lastFourDigits.allSatisfy(\.isNumber)
    }

    private func loadExistingValues() {
        guard case .edit(let card) = mode else { return }

        name = card.name
        lastFourDigits = card.lastFourDigits
        issuer = card.issuer ?? ""
        billingCycleDay = card.billingCycleDay
        paymentDueDay = card.paymentDueDay
        selectedColorHex = CardPaletteOption.matching(hex: card.colorHex) ?? CardPaletteOption.defaultHex
        notes = card.notes ?? ""
        isActive = card.isActive
        selectedOwnerID = card.ownerID
    }

    private func save() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIssuer = issuer.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let colorHex = CardPaletteOption.normalize(selectedColorHex)

        switch mode {
        case .create:
            let request = CreateCardRequest(
                name: trimmedName,
                lastFourDigits: lastFourDigits,
                issuer: trimmedIssuer.isEmpty ? nil : trimmedIssuer,
                billingCycleDay: billingCycleDay,
                paymentDueDay: paymentDueDay,
                colorHex: colorHex,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                ownerID: selectedOwnerID
            )
            if await cardsService.createCard(request) != nil {
                dismiss()
            }

        case .edit(let card):
            let request = UpdateCardRequest(
                name: trimmedName,
                lastFourDigits: lastFourDigits,
                issuer: trimmedIssuer.isEmpty ? nil : trimmedIssuer,
                billingCycleDay: billingCycleDay,
                paymentDueDay: paymentDueDay,
                colorHex: colorHex,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                isActive: isActive,
                ownerID: selectedOwnerID ?? card.ownerID
            )
            if await cardsService.updateCard(id: card.id, request) != nil {
                dismiss()
            }
        }
    }

    private func deleteCard() async {
        guard case .edit(let card) = mode else { return }
        if await cardsService.deleteCard(id: card.id) {
            dismiss()
        }
    }
}

#Preview {
    CardFormView(mode: .create)
        .environment(CardsAPIService())
        .environment(OwnersAPIService())
}
