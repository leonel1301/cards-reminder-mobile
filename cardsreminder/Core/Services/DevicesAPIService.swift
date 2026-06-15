import Foundation

struct DevicesAPIService {
    private let api = APIService.shared

    func register(
        fcmToken: String,
        platform: String = "ios",
        language: String
    ) async throws -> APIDevice {
        try await api.request(
            path: "/devices",
            method: "PUT",
            body: RegisterDeviceRequest(
                fcmToken: fcmToken,
                platform: platform,
                language: language
            )
        )
    }

    func unregister(fcmToken: String) async throws {
        try await api.requestVoid(
            path: "/devices",
            method: "DELETE",
            body: UnregisterDeviceRequest(fcmToken: fcmToken)
        )
    }
}
