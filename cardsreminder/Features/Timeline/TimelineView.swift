import SwiftUI
import UIKit

struct TimelineView: View {
    @Environment(CardsAPIService.self) private var cardsService
    @Environment(PaymentsAPIService.self) private var paymentsService

    @State private var paymentsCard: APICard?
    @State private var markingPaidCardID: UUID?
    @State private var isContentRevealed = false
    @State private var isFeelingExplanationPresented = false

    private var buildResult: TimelineBuildResult {
        TimelineEventBuilder.build(
            from: paymentsService.dashboardCards,
            excludingCardID: paymentsService.bestForPurchase?.cardID
        )
    }

    private var featuredEntry: DashboardCardEntry? {
        guard let bestForPurchase = paymentsService.bestForPurchase else { return nil }
        return paymentsService.dashboardCards.first { $0.card.id == bestForPurchase.cardID }
    }

    private var isInitialLoading: Bool {
        paymentsService.isLoadingDashboard && paymentsService.dashboardCards.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let errorMessage = paymentsService.errorMessage,
                       !paymentsService.hasCachedDashboard {
                        errorBanner(errorMessage)
                    }

                    if paymentsService.dashboardCards.isEmpty && !isInitialLoading {
                        emptyState
                            .transition(SmoothRevealAnimation.sectionTransition)
                    } else {
                        loadedContent
                            .transition(SmoothRevealAnimation.sectionTransition)
                    }
                }
                .padding(.bottom, 16)
                .animation(SmoothRevealAnimation.motion, value: paymentsService.dashboardRevision)
            }
            .refreshable {
                guard !isFeelingExplanationPresented else { return }
                await refreshTimeline()
                revealContent()
            }
        }
        .safeAreaPadding(.bottom)
        .overlay {
            if isInitialLoading {
                ProgressView()
            }
        }
        .onChange(of: paymentsService.dashboardRevision) { _, _ in
            revealContent()
        }
        .sheet(item: $paymentsCard) { card in
            CardPaymentsSheet(card: card)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("screen_timeline_title")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(alignment: .center, spacing: 12) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let summary = paymentsService.summary, !isInitialLoading {
                    FinanceFeelingButton(
                        feeling: DashboardFeeling(summary: summary),
                        isExplanationPresented: $isFeelingExplanationPresented
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var loadedContent: some View {
        if let summary = paymentsService.summary {
            TimelineSummaryStrip(
                summary: summary,
                revealDelay: SmoothRevealAnimation.staggerDelay(for: 0),
                isRevealed: isContentRevealed
            )
        }

        if let featuredEntry {
            VStack(alignment: .leading, spacing: 10) {
                TimelineFeaturedCard(
                    card: featuredEntry.card,
                    status: featuredEntry.status,
                    revealDelay: SmoothRevealAnimation.staggerDelay(for: 1),
                    isRevealed: isContentRevealed
                )
                .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .onTapGesture {
                    paymentsCard = featuredEntry.card
                }

                if let why = paymentsService.bestForPurchase?.why {
                    TimelinePurchaseInsightRow(
                        why: why,
                        revealDelay: SmoothRevealAnimation.staggerDelay(for: 2),
                        isRevealed: isContentRevealed
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }

        if buildResult.sections.isEmpty, featuredEntry == nil {
            allGoodState
                .padding(.horizontal, 16)
                .opacity(isContentRevealed ? 1 : 0)
                .scaleEffect(isContentRevealed ? 1 : 0.96)
                .animation(SmoothRevealAnimation.motion.delay(0.08), value: isContentRevealed)
        } else {
            timelineSections
        }
    }

    private var timelineSections: some View {
        let indexedSections = Self.indexedSections(from: buildResult.sections)

        return VStack(alignment: .leading, spacing: 24) {
            ForEach(Array(indexedSections.enumerated()), id: \.element.section.id) { sectionIndex, item in
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStringKey(item.section.titleKey))
                        .font(.headline)
                        .padding(.horizontal, 16)
                        .opacity(isContentRevealed ? 1 : 0)
                        .offset(y: isContentRevealed ? 0 : 6)
                        .animation(
                            SmoothRevealAnimation.motion.delay(
                                SmoothRevealAnimation.staggerDelay(for: sectionIndex + 2)
                            ),
                            value: isContentRevealed
                        )

                    VStack(spacing: 14) {
                        ForEach(Array(item.section.events.enumerated()), id: \.element.id) { eventIndex, event in
                            let globalIndex = item.startIndex + eventIndex

                            Button {
                                paymentsCard = event.card
                            } label: {
                                TimelineEventRow(
                                    event: event,
                                    isLast: true,
                                    revealDelay: SmoothRevealAnimation.staggerDelay(for: globalIndex + 3),
                                    isRevealed: isContentRevealed
                                )
                            }
                            .buttonStyle(.plain)
                            .overlay {
                                if markingPaidCardID == event.card.id {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .overlay { ProgressView() }
                                }
                            }
                            .contextMenu {
                                if canMarkPaid(event) {
                                    Button {
                                        Task { await quickMarkPaid(event.card) }
                                    } label: {
                                        Label("payments_mark_paid", systemImage: "checkmark.circle")
                                    }
                                }

                                Button {
                                    paymentsCard = event.card
                                } label: {
                                    Label("payments_view_history", systemImage: "clock.arrow.circlepath")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 36))
                .foregroundStyle(Color.secondaryText)

            Text("timeline_empty_title")
                .font(.subheadline.weight(.medium))

            Text("timeline_empty_message")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
        .padding(.horizontal, 24)
    }

    private var allGoodState: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundStyle(Color.emeraldStateForeground)

            Text("timeline_all_good_title")
                .font(.subheadline.weight(.medium))

            Text("timeline_all_good_message")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 20)
        .background(Color.emeraldStateBackground.opacity(0.45))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.red)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
    }

    private static func indexedSections(from sections: [TimelineSection]) -> [(section: TimelineSection, startIndex: Int)] {
        var startIndex = 0
        return sections.map { section in
            let item = (section: section, startIndex: startIndex)
            startIndex += section.events.count
            return item
        }
    }

    private func canMarkPaid(_ event: TimelineEvent) -> Bool {
        event.card.isActive
            && !event.status.isPaidThisCycle
            && (event.kind == .overdue || event.kind == .paymentDueToday || event.kind == .urgent || event.kind == .dueSoon)
    }

    private func refreshTimeline() async {
        async let cards: Void = cardsService.fetchCards(silentUnlessEmpty: false)
        async let dashboard: Void = paymentsService.fetchDashboard(silentUnlessEmpty: false)
        _ = await (cards, dashboard)
    }

    private func revealContent() {
        if paymentsService.dashboardCards.isEmpty {
            isContentRevealed = false
            return
        }

        isContentRevealed = false
        DispatchQueue.main.async {
            withAnimation(SmoothRevealAnimation.motion) {
                isContentRevealed = true
            }
        }
    }

    private func quickMarkPaid(_ card: APICard) async {
        markingPaidCardID = card.id
        defer { markingPaidCardID = nil }

        guard let response = await paymentsService.markAsPaid(cardID: card.id) else { return }

        if let index = cardsService.cards.firstIndex(where: { $0.id == response.card.id }) {
            cardsService.cards[index] = response.card
        }

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

#Preview {
    TimelineView()
        .environment(CardsAPIService())
        .environment(PaymentsAPIService())
}
