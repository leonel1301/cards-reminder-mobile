import SwiftData
import SwiftUI

private enum SettingsSheet: Identifiable {
    case createOwner
    case notifications
    case editOwner(APIOwner)

    var id: String {
        switch self {
        case .createOwner:
            "createOwner"
        case .notifications:
            "notifications"
        case .editOwner(let owner):
            owner.id.uuidString
        }
    }
}

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AuthManager.self) private var authManager
    @Environment(CardsAPIService.self) private var cardsService
    @Environment(PushNotificationManager.self) private var pushManager
    @Environment(UserAPIService.self) private var userService
    @Environment(OwnersAPIService.self) private var ownersService
    @Query private var profiles: [UserProfile]

    @State private var activeSheet: SettingsSheet?

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                screenHeader

                profileSection

                ownersSection

                if let errorMessage = userService.errorMessage ?? ownersService.errorMessage {
                    errorBanner(errorMessage)
                }
            }
            .padding(.bottom, 32)
        }
        .safeAreaPadding(.bottom)
        .task {
            if !userService.hasLoaded {
                await userService.fetchProfile(into: modelContext)
            }
            if !ownersService.hasLoaded {
                await ownersService.fetchOwners()
            }
        }
        .refreshable {
            await loadData()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .createOwner:
                OwnerFormView(mode: .create)
            case .notifications:
                NotificationsSettingsView()
            case .editOwner(let owner):
                OwnerFormView(mode: .edit(owner))
                    .id(owner.id)
            }
        }
    }

    private func loadData() async {
        await userService.fetchProfile(into: modelContext)
        await ownersService.fetchOwners()
    }

    private var screenHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("screen_settings_title")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            settingsMenu
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var settingsMenu: some View {
        Menu {
            Button {
                activeSheet = .notifications
            } label: {
                Label("action_notifications", systemImage: "bell")
            }

            Button(role: .destructive) {
                signOut()
            } label: {
                Label("action_logout", systemImage: "rectangle.portrait.and.arrow.right")
            }
        } label: {
            Image(systemName: "ellipsis")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
    }

    private func signOut() {
        Task {
            await pushManager.unregisterFromBackend()
            UserProfile.clearAll(in: modelContext)
            APIAlertCenter.shared.dismiss()
            cardsService.resetSession()
            ownersService.resetSession()
            userService.resetSession()
            authManager.signOut()
        }
    }

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("profile_section")
                .padding(.horizontal, 16)

            detailRow(
                icon: "calendar",
                title: String(localized: "field_member_since"),
                value: memberSinceText
            )
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    private var ownersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                sectionHeader("owners_section")

                if !ownersService.owners.isEmpty {
                    Text("\(ownersService.owners.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)

            Button {
                activeSheet = .createOwner
            } label: {
                Label("action_add_owner", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 16)

            if ownersService.isLoading && ownersService.owners.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .padding(.horizontal, 16)
            } else if ownersService.owners.isEmpty {
                Text("owners_empty_message")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(ownersService.owners) { owner in
                        Button {
                            activeSheet = .editOwner(owner)
                        } label: {
                            ownerRow(owner)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if owner.id != ownersService.owners.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
    }

    private func ownerRow(_ owner: APIOwner) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(owner.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)

                    if owner.isSelf {
                        Text("owner_self_badge")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(owner.salaryDayLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(message)
                .font(.caption)
                .foregroundStyle(.red)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var memberSinceText: String {
        guard let createdAt = profile?.createdAt else {
            return String(localized: "value_not_available")
        }
        return createdAt.formatted(.dateTime.day().month(.wide).year())
    }
}

#Preview {
    SettingsView()
        .environment(AuthManager())
        .environment(PushNotificationManager.shared)
        .environment(UserAPIService())
        .environment(OwnersAPIService())
        .modelContainer(for: UserProfile.self, inMemory: true)
}
