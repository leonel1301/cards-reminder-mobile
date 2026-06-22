import FirebaseAuth
import StoreKit
import SwiftData
import SwiftUI

private enum ProfileSheet: Identifiable {
    case createOwner
    case editOwner(APIOwner)

    var id: String {
        switch self {
        case .createOwner:
            "createOwner"
        case .editOwner(let owner):
            owner.id.uuidString
        }
    }
}

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview
    @Environment(AuthManager.self) private var authManager
    @Environment(PushNotificationManager.self) private var pushManager
    @Environment(UserAPIService.self) private var userService
    @Environment(OwnersAPIService.self) private var ownersService
    @Query private var profiles: [UserProfile]

    @State private var activeSheet: ProfileSheet?
    @State private var showSettings = false
    @State private var isFeedbackPresented = false
    @State private var presentedSafariURL: PresentedURL?

    private var profile: UserProfile? { profiles.first }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                screenHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        profileSection
                            .transition(SmoothRevealAnimation.sectionTransition)

                        ownersSection
                            .transition(SmoothRevealAnimation.sectionTransition)

                        moreAboutAppSection
                            .transition(SmoothRevealAnimation.sectionTransition)

                        appBrandingFooter
                            .transition(SmoothRevealAnimation.sectionTransition)

                        if let errorMessage = userService.errorMessage ?? ownersService.errorMessage {
                            errorBanner(errorMessage)
                        }
                    }
                    .padding(.bottom, 32)
                    .animation(SmoothRevealAnimation.motion, value: userService.contentRevision)
                    .animation(SmoothRevealAnimation.motion, value: ownersService.contentRevision)
                }
                .refreshable {
                    await loadData()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showSettings) {
                AppSettingsView()
            }
        }
        .safeAreaPadding(.bottom)
        .task {
            await loadInitialData()
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .createOwner:
                OwnerFormView(mode: .create)
            case .editOwner(let owner):
                OwnerFormView(mode: .edit(owner))
                    .id(owner.id)
            }
        }
        .sheet(isPresented: $isFeedbackPresented) {
            FeedbackSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .inAppSafariSheet(presentedURL: $presentedSafariURL)
    }

    private func loadInitialData() async {
        async let profile: Void = userService.fetchProfile(into: modelContext)
        if !ownersService.hasLoaded {
            async let owners: Void = ownersService.fetchOwners()
            _ = await (profile, owners)
        } else {
            await profile
        }
    }

    private func loadData() async {
        async let profile: Void = userService.fetchProfile(into: modelContext)
        async let owners: Void = ownersService.fetchOwners()
        _ = await (profile, owners)
    }

    private var screenHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("screen_profile_title")
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity, alignment: .leading)

            profileMenu
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .background(Color(.systemBackground))
    }

    private var profileMenu: some View {
        Menu {
            Button {
                Haptics.lightImpact()
                showSettings = true
            } label: {
                Label("action_settings", systemImage: "gearshape")
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
                        .transition(SmoothRevealAnimation.transition)
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
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
                    ForEach(Array(ownersService.owners.enumerated()), id: \.element.id) { index, owner in
                        Button {
                            activeSheet = .editOwner(owner)
                        } label: {
                            ownerRow(owner)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .transition(SmoothRevealAnimation.transition)
                        .animation(
                            SmoothRevealAnimation.motion.delay(SmoothRevealAnimation.staggerDelay(for: index)),
                            value: ownersService.contentRevision
                        )

                        if owner.id != ownersService.owners.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .transition(SmoothRevealAnimation.sectionTransition)
            }
        }
    }

    private var moreAboutAppSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("section_more_about_app")
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                rateAppActionRow
                feedbackActionRow
                actionRow(title: "action_faq", icon: "questionmark.circle", url: AppMetadata.faqURL)
            }
            .padding(.horizontal, 16)
        }
    }

    private var appBrandingFooter: some View {
        VStack(spacing: 8) {
            Text("app_description_short")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                openURL(AppLink.lenaraHomepage)
            } label: {
                HStack(spacing: 4) {
                    Text("footer_powered_by")
                        .foregroundStyle(.secondary)

                    Text("Lenara")
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)

                    Image(systemName: "arrow.up.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .font(.caption)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("footer_powered_by_lenara"))

            VStack(spacing: 2) {
                Text(
                    String(
                        format: String(localized: "footer_version_build"),
                        AppMetadata.version,
                        AppMetadata.build
                    )
                )
                Text(
                    String(
                        format: String(localized: "footer_user_email"),
                        userEmail
                    )
                )
            }
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var userEmail: String {
        if let email = profile?.email, !email.isEmpty {
            return email
        }
        if let email = authManager.user?.email, !email.isEmpty {
            return email
        }
        return String(localized: "value_not_available")
    }

    private var rateAppActionRow: some View {
        Button {
            requestReview()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "star")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text("action_rate_app")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var feedbackActionRow: some View {
        Button {
            isFeedbackPresented = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text("action_share_feedback")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func actionRow(title: LocalizedStringKey, icon: String, url: URL) -> some View {
        Button {
            AppLink.open(url, presentingIn: $presentedSafariURL, openURL: openURL)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
    ProfileView()
        .environment(AuthManager())
        .environment(PushNotificationManager.shared)
        .environment(UserAPIService())
        .environment(OwnersAPIService())
        .environment(FeedbackAPIService())
        .modelContainer(for: UserProfile.self, inMemory: true)
}
