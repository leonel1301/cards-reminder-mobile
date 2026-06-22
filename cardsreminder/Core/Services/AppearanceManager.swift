import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var labelKey: LocalizedStringKey {
        switch self {
        case .system: "theme_system"
        case .light: "theme_light"
        case .dark: "theme_dark"
        }
    }
}

@Observable
final class AppearanceManager {
    static let shared = AppearanceManager()

    private static let storageKey = "app_appearance"

    var appearance: AppAppearance {
        didSet {
            UserDefaults.standard.set(appearance.rawValue, forKey: Self.storageKey)
        }
    }

    private init() {
        let stored = UserDefaults.standard.string(forKey: Self.storageKey)
        appearance = AppAppearance(rawValue: stored ?? AppAppearance.system.rawValue) ?? .system
    }
}
