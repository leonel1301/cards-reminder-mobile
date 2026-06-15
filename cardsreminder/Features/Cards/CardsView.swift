import SwiftUI

struct CardsView: View {
    @Environment(CardsAPIService.self) private var cardsService
    @State private var showCreateForm = false
    @State private var editingCard: APICard?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                screenTitle

                addButton

                if let errorMessage = cardsService.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 16)
                }

                if cardsService.cards.isEmpty && !cardsService.isLoading {
                    emptyState
                } else {
                    cardsList
                }
            }
            .padding(.bottom, 16)
        }
        .safeAreaPadding(.bottom)
        .overlay {
            if cardsService.isLoading && cardsService.cards.isEmpty {
                ProgressView()
            }
        }
        .task {
            guard !cardsService.hasLoaded else { return }
            await cardsService.fetchCards()
        }
        .refreshable {
            await cardsService.fetchCards()
        }
        .sheet(isPresented: $showCreateForm) {
            CardFormView(mode: .create)
        }
        .sheet(item: $editingCard) { card in
            CardFormView(mode: .edit(card))
        }
    }

    private var screenTitle: some View {
        Text("screen_cards_title")
            .font(.largeTitle.bold())
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 8)
    }

    private var addButton: some View {
        Button {
            showCreateForm = true
        } label: {
            Label("action_add_card", systemImage: "plus.circle.fill")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("cards_empty_title")
                .font(.subheadline.weight(.medium))
            Text("cards_empty_message")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .padding(.horizontal, 24)
    }

    private var cardsList: some View {
        VStack(spacing: 16) {
            ForEach(cardsService.cards) { card in
                Button {
                    editingCard = card
                } label: {
                    CreditCardView(card: card)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
    }
}

#Preview {
    CardsView()
        .environment(CardsAPIService())
}
