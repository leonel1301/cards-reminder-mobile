import SwiftUI

enum ProfileInitials {
    /// Two letters at most: the first and last word of the name, falling back to
    /// the email when the account has no display name yet.
    static func resolve(name: String?, email: String?) -> String {
        let letters = (name ?? "")
            .split(whereSeparator: \.isWhitespace)
            .compactMap { $0.first(where: \.isLetter) }

        if let first = letters.first {
            guard letters.count > 1, let last = letters.last else {
                return String(first).uppercased()
            }
            return String([first, last]).uppercased()
        }

        if let letter = (email ?? "").first(where: \.isLetter) {
            return String(letter).uppercased()
        }

        return ""
    }
}

struct ProfileIdentityCard: View {
    let name: String?
    let email: String?
    let memberSince: String?

    @ScaledMetric(relativeTo: .title3) private var avatarSize: CGFloat = 56

    private var initials: String {
        ProfileInitials.resolve(name: name, email: email)
    }

    private var resolvedName: String {
        guard let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return String(localized: "profile_identity_fallback_name")
        }
        return name
    }

    var body: some View {
        HStack(spacing: 14) {
            avatar

            VStack(alignment: .leading, spacing: 3) {
                Text(resolvedName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let email, !email.isEmpty {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                if let memberSince {
                    Text(memberSince)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sectionCard()
        .accessibilityElement(children: .combine)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(Color.primaryAction.opacity(0.14))

            if initials.isEmpty {
                Image(systemName: "person.fill")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primaryAction)
            } else {
                Text(initials)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.primaryAction)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                    .padding(4)
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 16) {
        ProfileIdentityCard(
            name: "Leonel Ortega",
            email: "leonel@example.com",
            memberSince: "Miembro desde 3 de marzo de 2025"
        )

        ProfileIdentityCard(
            name: nil,
            email: "sinnombre@example.com",
            memberSince: nil
        )
    }
    .padding(16)
    .background(Color.appBackground)
}
