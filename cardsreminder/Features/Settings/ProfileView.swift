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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AuthManager.self) private var authManager
    @Environment(UserAPIService.self) private var userService
    @Environment(OwnersAPIService.self) private var ownersService
    @Environment(CardsAPIService.self) private var cardsService
    @Query private var profiles: [UserProfile]

    @State private var activeSheet: ProfileSheet?
    @State private var showSettings = false
    @State private var isFeedbackPresented = false
    @State private var presentedSafariURL: PresentedURL?
    @State private var openSwipeOwnerID: String?
    @State private var ownerPendingDeletion: APIOwner?

    private var profile: UserProfile? { profiles.first }

    private var motion: Animation? {
        SmoothRevealAnimation.motion(reduceMotion: reduceMotion)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    errorBanner

                    ProfileIdentityCard(
                        name: displayName,
                        email: userEmail,
                        memberSince: memberSinceText
                    )

                    ProfileOwnersSection(
                        owners: ownersService.owners,
                        isLoading: ownersService.isLoading,
                        contentRevision: ownersService.contentRevision,
                        cardCount: { cardCount(for: $0) },
                        openSwipeOwnerID: $openSwipeOwnerID,
                        onAdd: { activeSheet = .createOwner },
                        onEdit: { activeSheet = .editOwner($0) },
                        onDelete: { ownerPendingDeletion = $0 }
                    )

                    moreAboutAppSection

                    appBrandingFooter
                }
                .padding(.horizontal, 16)
                .padding(.top, 4)
                .padding(.bottom, 32)
                .animation(motion, value: userService.contentRevision)
                .animation(motion, value: ownersService.contentRevision)
            }
            .background(Color.appBackground)
            .navigationTitle("screen_profile_title")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Haptics.lightImpact()
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.semibold))
                    }
                    .accessibilityLabel(Text("action_settings"))
                }
            }
            .refreshable {
                await loadData()
            }
            .navigationDestination(isPresented: $showSettings) {
                AppSettingsView()
            }
        }
        .task {
            await loadInitialData()
        }
        .onChange(of: ownersService.contentRevision) { _, _ in
            openSwipeOwnerID = nil
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
        .alert(
            "delete_owner_confirm_title",
            isPresented: isDeletingOwner,
            presenting: ownerPendingDeletion
        ) { owner in
            Button("action_cancel", role: .cancel) {
                ownerPendingDeletion = nil
            }
            Button("action_delete", role: .destructive) {
                Task { await deleteOwner(owner) }
            }
        } message: { owner in
            Text(owner.name)
        }
        .inAppSafariSheet(presentedURL: $presentedSafariURL)
    }

    private var isDeletingOwner: Binding<Bool> {
        Binding(
            get: { ownerPendingDeletion != nil },
            set: { presented in
                if !presented { ownerPendingDeletion = nil }
            }
        )
    }

    private func loadInitialData() async {
        async let profile: Void = userService.fetchProfile(into: modelContext)

        if ownersService.hasLoaded {
            await profile
        } else {
            async let owners: Void = ownersService.fetchOwners()
            _ = await (profile, owners)
        }
    }

    private func loadData() async {
        async let profile: Void = userService.fetchProfile(into: modelContext)
        async let owners: Void = ownersService.fetchOwners()
        _ = await (profile, owners)
    }

    /// `nil` until cards arrive, so a row never claims an owner has none while
    /// the list is still in flight.
    private func cardCount(for owner: APIOwner) -> Int? {
        guard cardsService.hasLoaded else { return nil }
        return cardsService.cards.filter { $0.ownerID == owner.id }.count
    }

    private func deleteOwner(_ owner: APIOwner) async {
        ownerPendingDeletion = nil

        guard await ownersService.deleteOwner(id: owner.id) else { return }

        Haptics.success()
        // Cards may have been reassigned or removed server side.
        await cardsService.fetchCards(silentUnlessEmpty: false)
    }

    private var moreAboutAppSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("section_more_about_app")

            VStack(spacing: 0) {
                actionRow(title: "action_rate_app", icon: "star") {
                    requestReview()
                }

                Divider().padding(.leading, 56)

                actionRow(title: "action_share_feedback", icon: "bubble.left.and.bubble.right") {
                    isFeedbackPresented = true
                }

                Divider().padding(.leading, 56)

                actionRow(title: "action_faq", icon: "questionmark.circle") {
                    AppLink.open(AppMetadata.faqURL, presentingIn: $presentedSafariURL, openURL: openURL)
                }
            }
            .sectionCard()
        }
    }

    private var appBrandingFooter: some View {
        VStack(spacing: 8) {
            Text("app_description_short")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            PoweredByLenaraFooter()

            Text(
                String(
                    format: String(localized: "footer_version_build"),
                    AppMetadata.version,
                    AppMetadata.build
                )
            )
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    private var displayName: String? {
        if let name = profile?.displayName, !name.isEmpty {
            return name
        }
        return authManager.user?.displayName
    }

    private var userEmail: String? {
        if let email = profile?.email, !email.isEmpty {
            return email
        }
        return authManager.user?.email
    }

    private var memberSinceText: String? {
        guard let createdAt = profile?.createdAt else { return nil }

        return String(
            format: String(localized: "profile_member_since_value"),
            createdAt.formatted(.dateTime.day().month(.wide).year())
        )
    }

    private func actionRow(
        title: LocalizedStringKey,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.lightImpact()
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.primaryAction)
                    .frame(width: 28, height: 28)
                    .background(
                        Color.primaryAction.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let message = userService.errorMessage ?? ownersService.errorMessage {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.amberStateForeground)

                Text(message)
                    .font(.caption)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button("action_retry") {
                    Task { await loadData() }
                }
                .font(.caption.weight(.semibold))
            }
            .padding(12)
            .background(
                Color.amberStateBackground.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

#Preview {
    ProfileView()
        .environment(AuthManager())
        .environment(AppearanceManager.shared)
        .environment(PushNotificationManager.shared)
        .environment(UserAPIService())
        .environment(OwnersAPIService())
        .environment(CardsAPIService())
        .environment(FeedbackAPIService())
        .modelContainer(for: UserProfile.self, inMemory: true)
}
