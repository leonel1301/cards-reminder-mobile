import SwiftUI

struct TreeHealth: Equatable {
    enum Stage: String, Equatable {
        case dormant
        case withered
        case struggling
        case growing
        case healthy
        case thriving
    }

    let score: Double
    let stage: Stage

    var canopyScale: Double {
        switch stage {
        case .dormant: 0.28
        case .withered: 0.12
        case .struggling: 0.42
        case .growing: 0.62
        case .healthy: 0.84
        case .thriving: 1.0
        }
    }

    var leafDensity: Double {
        switch stage {
        case .dormant: 0.22
        case .withered: 0.04
        case .struggling: 0.32
        case .growing: 0.55
        case .healthy: 0.82
        case .thriving: 1.0
        }
    }

    var droop: Double {
        switch stage {
        case .dormant: 0.08
        case .withered: 0.92
        case .struggling: 0.58
        case .growing: 0.28
        case .healthy: 0.1
        case .thriving: 0.0
        }
    }

    var titleKey: String { "tree_health_title_\(stage.rawValue)" }
    var subtitleKey: String { "tree_health_subtitle_\(stage.rawValue)" }

    var canopyColor: Color {
        switch stage {
        case .dormant: Color(red: 0.62, green: 0.78, blue: 0.42)
        case .withered: Color(red: 0.42, green: 0.32, blue: 0.22)
        case .struggling: Color(red: 0.62, green: 0.52, blue: 0.22)
        case .growing: Color(red: 0.45, green: 0.68, blue: 0.32)
        case .healthy: Color(red: 0.28, green: 0.66, blue: 0.36)
        case .thriving: Color(red: 0.18, green: 0.72, blue: 0.38)
        }
    }

    var skyTopColor: Color {
        skyTopColor(for: .light)
    }

    var skyBottomColor: Color {
        skyBottomColor(for: .light)
    }

    func skyTopColor(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            switch stage {
            case .dormant: Color(red: 0.07, green: 0.09, blue: 0.18)
            case .withered: Color(red: 0.16, green: 0.07, blue: 0.08)
            case .struggling: Color(red: 0.16, green: 0.1, blue: 0.08)
            case .growing: Color(red: 0.08, green: 0.1, blue: 0.22)
            case .healthy, .thriving: Color(red: 0.05, green: 0.07, blue: 0.2)
            }
        } else {
            switch stage {
            case .dormant: Color(red: 0.55, green: 0.72, blue: 0.9)
            case .withered: Color(red: 0.62, green: 0.48, blue: 0.4)
            case .struggling: Color(red: 0.7, green: 0.62, blue: 0.48)
            case .growing: Color(red: 0.52, green: 0.74, blue: 0.94)
            case .healthy, .thriving: Color(red: 0.48, green: 0.76, blue: 0.98)
            }
        }
    }

    func skyBottomColor(for colorScheme: ColorScheme) -> Color {
        if colorScheme == .dark {
            switch stage {
            case .dormant: Color(red: 0.12, green: 0.14, blue: 0.26)
            case .withered: Color(red: 0.22, green: 0.1, blue: 0.1)
            case .struggling: Color(red: 0.24, green: 0.16, blue: 0.1)
            case .growing: Color(red: 0.12, green: 0.16, blue: 0.32)
            case .healthy, .thriving: Color(red: 0.1, green: 0.14, blue: 0.34)
            }
        } else {
            switch stage {
            case .dormant: Color(red: 0.78, green: 0.86, blue: 0.94)
            case .withered: Color(red: 0.78, green: 0.62, blue: 0.48)
            case .struggling: Color(red: 0.86, green: 0.78, blue: 0.58)
            case .growing: Color(red: 0.78, green: 0.9, blue: 0.98)
            case .healthy, .thriving: Color(red: 0.82, green: 0.92, blue: 1)
            }
        }
    }

    var trunkColor: Color {
        switch stage {
        case .dormant: Color(red: 0.55, green: 0.42, blue: 0.28)
        case .withered: Color(red: 0.28, green: 0.24, blue: 0.2)
        case .struggling: Color(red: 0.4, green: 0.3, blue: 0.2)
        case .growing, .healthy, .thriving: Color(red: 0.48, green: 0.32, blue: 0.18)
        }
    }

    var oceanColor: Color {
        switch stage {
        case .dormant: Color(red: 0.55, green: 0.64, blue: 0.72)
        case .withered: Color(red: 0.38, green: 0.28, blue: 0.22)
        case .struggling: Color(red: 0.42, green: 0.48, blue: 0.46)
        case .growing: Color(red: 0.28, green: 0.5, blue: 0.68)
        case .healthy: Color(red: 0.18, green: 0.46, blue: 0.78)
        case .thriving: Color(red: 0.12, green: 0.42, blue: 0.82)
        }
    }

    var landColor: Color {
        switch stage {
        case .dormant: Color(red: 0.62, green: 0.58, blue: 0.46)
        case .withered: Color(red: 0.42, green: 0.3, blue: 0.2)
        case .struggling: Color(red: 0.58, green: 0.5, blue: 0.28)
        case .growing: Color(red: 0.42, green: 0.58, blue: 0.3)
        case .healthy: Color(red: 0.28, green: 0.58, blue: 0.3)
        case .thriving: Color(red: 0.2, green: 0.62, blue: 0.32)
        }
    }

    var atmosphereColor: Color {
        switch stage {
        case .dormant: Color(red: 0.7, green: 0.76, blue: 0.82).opacity(0.18)
        case .withered: Color(red: 0.7, green: 0.28, blue: 0.16).opacity(0.22)
        case .struggling: Color(red: 0.72, green: 0.5, blue: 0.28).opacity(0.16)
        case .growing: Color(red: 0.55, green: 0.75, blue: 0.9).opacity(0.16)
        case .healthy: Color(red: 0.45, green: 0.72, blue: 1).opacity(0.18)
        case .thriving: Color(red: 0.4, green: 0.75, blue: 1).opacity(0.22)
        }
    }

    init(summary: DashboardSummary?) {
        guard let summary, summary.total > 0 else {
            score = 0.28
            stage = .dormant
            return
        }

        let total = Double(summary.total)
        let weighted = (
            Double(summary.paid) * 1.0
            + Double(summary.optimalDay) * 0.9
            + Double(summary.onTrack) * 0.82
            + Double(summary.dueSoon) * 0.42
            + Double(summary.urgent) * 0.18
            + Double(summary.overdue) * 0.0
        ) / total

        var computed = weighted

        if summary.overdue > 0 {
            computed = min(computed, 0.28)
            computed -= min(0.18, Double(summary.overdue) / total * 0.22)
        } else if summary.urgent > 0 {
            computed = min(computed, 0.48)
        }

        if summary.paid == summary.total {
            computed = 1.0
        }

        computed = min(1, max(0, computed))
        score = computed
        stage = Self.stage(for: computed, summary: summary)
    }

    private static func stage(for score: Double, summary: DashboardSummary) -> Stage {
        if summary.paid == summary.total {
            return .thriving
        }
        if summary.overdue > 0 || score < 0.22 {
            return .withered
        }
        if score < 0.42 {
            return .struggling
        }
        if score < 0.64 {
            return .growing
        }
        if score < 0.9 {
            return .healthy
        }
        return .thriving
    }
}
