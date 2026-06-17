import FirebaseAuth
import UIKit
import UserNotifications

enum NotificationPreference {
    private static let legacyEnabledKey = "notificationsEnabled"
    private static let keyPrefix = "notificationsEnabled."

    static func enabledKey(for firebaseUID: String) -> String {
        "\(keyPrefix)\(firebaseUID)"
    }

    static func isEnabled(for firebaseUID: String?) -> Bool {
        guard let firebaseUID else { return false }
        return UserDefaults.standard.bool(forKey: enabledKey(for: firebaseUID))
    }

    static func setEnabled(_ enabled: Bool, for firebaseUID: String?) {
        guard let firebaseUID else { return }
        UserDefaults.standard.set(enabled, forKey: enabledKey(for: firebaseUID))
    }

    static func removeLegacyGlobalPreference() {
        UserDefaults.standard.removeObject(forKey: legacyEnabledKey)
    }
}

@Observable
@MainActor
final class PushNotificationManager {
    static let shared = PushNotificationManager()

    var authorizationStatus: UNAuthorizationStatus = .notDetermined
    var fcmToken: String?
    var registrationError: String?
    var isSyncingDevice = false
    private(set) var preferenceRevision = 0

    var isAuthorized: Bool {
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            true
        default:
            false
        }
    }

    var isNotificationsPreferenceEnabled: Bool {
        NotificationPreference.isEnabled(for: Auth.auth().currentUser?.uid)
    }

    private let devicesAPI = DevicesAPIService()

    private init() {
        NotificationPreference.removeLegacyGlobalPreference()
    }

    static var backendLanguageCode: String {
        Locale.current.language.languageCode?.identifier ?? "es"
    }

    static var backendTimezoneIdentifier: String {
        TimeZone.current.identifier
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func handleUserSessionChange(userSwitched: Bool) async {
        registrationError = nil

        if userSwitched {
            await unregisterFromBackend()
        }

        await refreshAuthorizationStatus()

        if authorizationStatus == .denied, isNotificationsPreferenceEnabled {
            setNotificationsPreferenceEnabled(false)
        }

        await syncDeviceWithBackendIfNeeded()
    }

    func applyNotificationsPreference(enabled: Bool) async {
        registrationError = nil

        if enabled {
            await requestAuthorization()
            guard isAuthorized else {
                setNotificationsPreferenceEnabled(false)
                return
            }

            setNotificationsPreferenceEnabled(true)
            UIApplication.shared.registerForRemoteNotifications()
            await syncDeviceWithBackendIfNeeded()
        } else {
            setNotificationsPreferenceEnabled(false)
            await unregisterFromBackend()
        }
    }

    func requestAuthorization() async {
        registrationError = nil

        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            await refreshAuthorizationStatus()

            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
        } catch {
            registrationError = error.localizedDescription
            await refreshAuthorizationStatus()
        }
    }

    func updateFCMToken(_ token: String?) {
        guard let token, !token.isEmpty else { return }
        fcmToken = token

        Task {
            await syncDeviceWithBackendIfNeeded()
        }
    }

    func syncDeviceWithBackendIfNeeded() async {
        guard isNotificationsPreferenceEnabled else { return }
        guard Auth.auth().currentUser != nil else { return }
        guard isAuthorized else { return }
        guard let token = fcmToken else { return }

        isSyncingDevice = true
        registrationError = nil
        defer { isSyncingDevice = false }

        do {
            _ = try await devicesAPI.register(
                fcmToken: token,
                language: Self.backendLanguageCode,
                timezone: Self.backendTimezoneIdentifier
            )
        } catch {
            if !error.isCancelled {
                registrationError = error.localizedDescription
            }
        }
    }

    func unregisterFromBackend() async {
        guard let token = fcmToken else { return }

        isSyncingDevice = true
        defer { isSyncingDevice = false }

        do {
            try await devicesAPI.unregister(fcmToken: token)
        } catch {
            if !error.isCancelled {
                registrationError = error.localizedDescription
            }
        }
    }

    func clearNotificationsPreferenceForCurrentUser() {
        setNotificationsPreferenceEnabled(false)
    }

    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func setNotificationsPreferenceEnabled(_ enabled: Bool) {
        NotificationPreference.setEnabled(enabled, for: Auth.auth().currentUser?.uid)
        preferenceRevision += 1
    }
}

private extension Error {
    var isCancelled: Bool {
        if self is CancellationError { return true }
        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled
    }
}
