import Foundation
import SwiftUI

@Observable
@MainActor
final class PaymentsAPIService {
    private(set) var statusByCardID: [UUID: APICardStatus] = [:]
    private(set) var dashboardCards: [DashboardCardEntry] = []
    private(set) var summary: DashboardSummary?
    private(set) var bestForPurchase: BestForPurchase?
    private(set) var dashboardRevision = 0
    private(set) var isLoadingDashboard = false
    var isLoading = false
    var errorMessage: String?

    private let api = APIService.shared

    func resetSession() {
        statusByCardID = [:]
        dashboardCards = []
        summary = nil
        bestForPurchase = nil
        dashboardRevision = 0
        isLoadingDashboard = false
        errorMessage = nil
        isLoading = false
    }

    func status(for cardID: UUID) -> APICardStatus? {
        statusByCardID[cardID]
    }

    func fetchDashboard() async {
        isLoadingDashboard = true
        defer { isLoadingDashboard = false }

        do {
            let response: DashboardResponse = try await api.request(path: "/dashboard")
            withAnimation(SmoothRevealAnimation.motion) {
                summary = response.summary
                bestForPurchase = response.bestForPurchase
                dashboardCards = response.cards.filter(\.card.isActive)
                for entry in response.cards {
                    statusByCardID[entry.card.id] = entry.status
                }
                dashboardRevision += 1
            }
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
        }
    }

    func fetchCardStatus(cardID: UUID) async -> CardStatusResponse? {
        do {
            let response: CardStatusResponse = try await api.request(
                path: "/cards/\(cardID.uuidString)/status"
            )
            statusByCardID[cardID] = response.status
            return response
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return nil
        }
    }

    func fetchCurrentCycle(cardID: UUID) async -> CurrentCycleResponse? {
        do {
            let response: CurrentCycleResponse = try await api.request(
                path: "/cards/\(cardID.uuidString)/current-cycle"
            )
            statusByCardID[cardID] = response.status
            return response
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return nil
        }
    }

    func fetchOptimalPurchaseDays(cardID: UUID) async -> OptimalPurchaseDaysResponse? {
        do {
            return try await api.request(
                path: "/cards/\(cardID.uuidString)/optimal-purchase-days"
            )
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return nil
        }
    }

    func fetchPayments(cardID: UUID) async -> CardPaymentsResponse? {
        do {
            return try await api.request(path: "/cards/\(cardID.uuidString)/payments")
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return nil
        }
    }

    @discardableResult
    func markAsPaid(cardID: UUID, notes: String? = nil) async -> MarkPaidResponse? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let body = MarkPaidRequest(notes: notes)
            let response: MarkPaidResponse = try await api.request(
                path: "/cards/\(cardID.uuidString)/payments",
                method: "POST",
                body: body
            )
            statusByCardID[cardID] = response.status
            await fetchDashboard()
            return response
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return nil
        }
    }
}
