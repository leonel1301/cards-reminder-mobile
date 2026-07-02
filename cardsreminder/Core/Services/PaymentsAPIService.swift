import FirebaseAnalytics
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
    private var fetchDashboardTask: Task<Void, Never>?

    var hasCachedDashboard: Bool {
        !dashboardCards.isEmpty || summary != nil
    }

    func resetSession() {
        cancelInFlightRequests()
        statusByCardID = [:]
        dashboardCards = []
        summary = nil
        bestForPurchase = nil
        dashboardRevision = 0
        isLoadingDashboard = false
        errorMessage = nil
        isLoading = false
    }

    func cancelInFlightRequests() {
        fetchDashboardTask?.cancel()
    }

    func resumeOnForeground() async {
        if hasCachedDashboard {
            errorMessage = nil
            await fetchDashboard(silentUnlessEmpty: true, maxAttempts: 3)
        } else if fetchDashboardTask == nil {
            await fetchDashboard()
        }
    }

    func status(for cardID: UUID) -> APICardStatus? {
        statusByCardID[cardID]
    }

    func fetchDashboard(silentUnlessEmpty: Bool = true, maxAttempts: Int = 1) async {
        if let fetchDashboardTask {
            await fetchDashboardTask.value
            return
        }

        let task = Task { @MainActor in
            isLoadingDashboard = true
            if !silentUnlessEmpty || !hasCachedDashboard {
                errorMessage = nil
            }

            defer {
                isLoadingDashboard = false
                fetchDashboardTask = nil
            }

            let attempts = max(1, maxAttempts)

            for attempt in 1...attempts {
                if Task.isCancelled { return }

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
                    errorMessage = nil
                    return
                } catch {
                    guard !error.isRequestCancelled else { return }

                    if attempt < attempts {
                        try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                        continue
                    }

                    guard !silentUnlessEmpty || !hasCachedDashboard else { return }
                    APIErrorHandling.handle(error) { errorMessage = $0 }
                }
            }
        }

        fetchDashboardTask = task
        await task.value
    }

    func fetchCardStatus(cardID: UUID) async -> CardStatusResponse? {
        do {
            let response: CardStatusResponse = try await api.request(
                path: "/cards/\(cardID.uuidString)/status"
            )
            statusByCardID[cardID] = response.status
            return response
        } catch {
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
            return nil
        }
    }

    func fetchOptimalPurchaseDays(cardID: UUID) async -> OptimalPurchaseDaysResponse? {
        do {
            let response: OptimalPurchaseDaysResponse = try await api.request(
                path: "/cards/\(cardID.uuidString)/optimal-purchase-days"
            )
            Analytics.logEvent("purchase_day_checked", parameters: nil)
            return response
        } catch {
            return nil
        }
    }

    func fetchPayments(cardID: UUID) async -> CardPaymentsResponse? {
        do {
            return try await api.request(path: "/cards/\(cardID.uuidString)/payments")
        } catch {
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
            await fetchDashboard(silentUnlessEmpty: false, maxAttempts: 2)
            Analytics.logEvent("payment_completed", parameters: nil)
            return response
        } catch {
            APIErrorHandling.handle(error) { errorMessage = $0 }
            return nil
        }
    }
}

private extension Error {
    var isRequestCancelled: Bool {
        if self is CancellationError { return true }
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
