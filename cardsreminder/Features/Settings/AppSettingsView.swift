import SwiftData
import SwiftUI

struct AppSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(AuthManager.self) private var authManager
    @Environment(PushNotificationManager.self) private var pushManager
    @Environment(UserAPIService.self) private var userService
    @Environment(AppearanceManager.self) private var appearanceManager

    @State private var showNotifications = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isDeletingAccount = false
    @State private var presentedSafariURL: PresentedURL?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                preferencesSection
                accountSection
                otherSection
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("screen_settings_title")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showNotifications) {
            NotificationsSettingsView()
        }
        .alert("delete_account_confirm_title", isPresented: $showDeleteAccountConfirmation) {
            Button("action_cancel", role: .cancel) {}
            Button("action_delete", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("delete_account_confirm_message")
        }
        .overlay {
            if isDeletingAccount {
                ProgressView()
            }
        }
        .inAppSafariSheet(presentedURL: $presentedSafariURL)
    }

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("section_preferences")
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                settingsActionRow(title: "action_notifications", icon: "bell") {
                    showNotifications = true
                }

                themeRow
            }
            .padding(.horizontal, 16)
        }
    }

    private var themeRow: some View {
        HStack(spacing: 12) {
            settingsIcon("circle.lefthalf.filled")

            Text("field_theme")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)

            Spacer(minLength: 0)

            Picker("", selection: Bindable(appearanceManager).appearance) {
                ForEach(AppAppearance.allCases) { option in
                    Text(option.labelKey).tag(option)
                }
            }
            .labelsHidden()
            .tint(.primary)
            .onChange(of: appearanceManager.appearance) { _, _ in
                Haptics.selection()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("section_account")
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                settingsActionRow(
                    title: "action_delete_account",
                    icon: "trash",
                    isDestructive: true
                ) {
                    showDeleteAccountConfirmation = true
                }

                settingsActionRow(
                    title: "action_sign_out",
                    icon: "rectangle.portrait.and.arrow.right",
                    isDestructive: true
                ) {
                    signOut()
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var otherSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("section_other")
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                settingsActionRow(title: "action_privacy_policy", icon: "hand.raised") {
                    AppLink.open(AppMetadata.privacyURL, presentingIn: $presentedSafariURL, openURL: openURL)
                }

                settingsActionRow(title: "action_terms_of_service", icon: "doc.text") {
                    AppLink.open(AppMetadata.termsURL, presentingIn: $presentedSafariURL, openURL: openURL)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func settingsIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(width: 28, height: 28)
    }

    private func settingsActionRow(
        title: LocalizedStringKey,
        icon: String,
        isDestructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                settingsIcon(icon)

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Color.primary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func signOut() {
        Task {
            await pushManager.unregisterFromBackend()
            UserProfile.clearAll(in: modelContext)
            authManager.signOut()
        }
    }

    private func deleteAccount() async {
        guard !isDeletingAccount else { return }
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        guard await userService.deleteAccount() else { return }

        await pushManager.unregisterFromBackend()
        UserProfile.clearAll(in: modelContext)
        authManager.signOut()
    }
}

#Preview {
    NavigationStack {
        AppSettingsView()
    }
    .environment(AuthManager())
    .environment(PushNotificationManager.shared)
    .environment(UserAPIService())
    .environment(AppearanceManager.shared)
    .modelContainer(for: UserProfile.self, inMemory: true)
}
