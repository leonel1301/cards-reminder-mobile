import SwiftUI
import FirebaseAuth

struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AuthManager.self) private var authManager
    @Environment(PushNotificationManager.self) private var pushManager

    private var notificationsEnabled: Bool {
        pushManager.isNotificationsPreferenceEnabled
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("notifications_enable_toggle", isOn: notificationsToggle)
                        .disabled(pushManager.authorizationStatus == .denied)
                } footer: {
                    Text("notifications_toggle_footer")
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: statusIcon)
                            .font(.title2)
                            .foregroundStyle(statusColor)
                            .frame(width: 32)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(statusTitle)
                                .font(.headline)

                            Text(statusDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if pushManager.authorizationStatus == .denied {
                    Section {
                        Button("notifications_open_settings") {
                            pushManager.openSystemSettings()
                        }
                    }
                }

                if pushManager.isSyncingDevice {
                    Section {
                        HStack {
                            ProgressView()
                            Text("notifications_syncing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let error = pushManager.registrationError {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                #if DEBUG
                if let token = pushManager.fcmToken {
                    Section("notifications_debug_token_section") {
                        Text(token)
                            .font(.caption2.monospaced())
                            .textSelection(.enabled)
                    }
                }
                #endif
            }
            .id("\(authManager.user?.uid ?? "guest")-\(pushManager.preferenceRevision)")
            .navigationTitle("screen_notifications_title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("action_cancel") { dismiss() }
                }
            }
            .task(id: authManager.user?.uid) {
                await pushManager.refreshAuthorizationStatus()

                if pushManager.authorizationStatus == .denied, notificationsEnabled {
                    pushManager.clearNotificationsPreferenceForCurrentUser()
                } else if notificationsEnabled {
                    await pushManager.syncDeviceWithBackendIfNeeded()
                }
            }
        }
    }

    private var notificationsToggle: Binding<Bool> {
        Binding(
            get: { pushManager.isNotificationsPreferenceEnabled },
            set: { newValue in
                Task {
                    await pushManager.applyNotificationsPreference(enabled: newValue)
                }
            }
        )
    }

    private var statusIcon: String {
        pushManager.isAuthorized && notificationsEnabled ? "bell.badge.fill" : "bell.slash"
    }

    private var statusColor: Color {
        pushManager.isAuthorized && notificationsEnabled ? .green : .secondary
    }

    private var statusTitle: LocalizedStringKey {
        if notificationsEnabled && pushManager.isAuthorized {
            "notifications_status_enabled"
        } else if pushManager.authorizationStatus == .denied {
            "notifications_status_denied"
        } else {
            "notifications_status_disabled"
        }
    }

    private var statusDescription: LocalizedStringKey {
        if notificationsEnabled && pushManager.isAuthorized {
            "notifications_description_enabled"
        } else if pushManager.authorizationStatus == .denied {
            "notifications_description_denied"
        } else {
            "notifications_description_disabled"
        }
    }
}

#Preview {
    NotificationsSettingsView()
        .environment(AuthManager())
        .environment(PushNotificationManager.shared)
}
