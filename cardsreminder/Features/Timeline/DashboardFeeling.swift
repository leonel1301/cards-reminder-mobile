import Foundation
import SwiftUI

struct DashboardFeeling: Equatable {
    enum Kind: Equatable {
        case redZone
        case crunchTime
        case countdown
        case primeWindow
        case cruising
        case clearBooks
        case blankSlate
    }

    let kind: Kind
    let summary: DashboardSummary

    init(summary: DashboardSummary) {
        self.summary = summary

        if summary.total == 0 {
            kind = .blankSlate
        } else if summary.overdue > 0 {
            kind = .redZone
        } else if summary.urgent > 0 {
            kind = .crunchTime
        } else if summary.dueSoon > 0 {
            kind = .countdown
        } else if summary.optimalDay > 0 {
            kind = .primeWindow
        } else if summary.paid == summary.total {
            kind = .clearBooks
        } else {
            kind = .cruising
        }
    }

    var iconName: String {
        switch kind {
        case .redZone: "exclamationmark.triangle.fill"
        case .crunchTime: "flame.fill"
        case .countdown: "clock.fill"
        case .primeWindow: "sparkles"
        case .cruising: "chart.line.uptrend.xyaxis"
        case .clearBooks: "lock.fill"
        case .blankSlate: "creditcard"
        }
    }

    var accentColor: Color {
        switch kind {
        case .redZone: Color.redStateForeground
        case .crunchTime: Color.amberStateForeground
        case .countdown: Color.violetStateForeground
        case .primeWindow: Color.violetStateForeground
        case .cruising: Color.emeraldStateForeground
        case .clearBooks: Color.emeraldStateForeground
        case .blankSlate: Color.secondary
        }
    }

    var usesAttentionPulse: Bool {
        switch kind {
        case .redZone, .crunchTime, .countdown: true
        default: false
        }
    }

    var wordKey: String {
        switch kind {
        case .redZone: "finance_feeling_red_zone"
        case .crunchTime: "finance_feeling_crunch"
        case .countdown: "finance_feeling_countdown"
        case .primeWindow: "finance_feeling_prime"
        case .cruising: "finance_feeling_cruising"
        case .clearBooks: "finance_feeling_clear"
        case .blankSlate: "finance_feeling_blank"
        }
    }

    var headlineKey: String {
        switch kind {
        case .redZone: "finance_feeling_headline_red_zone"
        case .crunchTime: "finance_feeling_headline_crunch"
        case .countdown: "finance_feeling_headline_countdown"
        case .primeWindow: "finance_feeling_headline_prime"
        case .cruising: "finance_feeling_headline_cruising"
        case .clearBooks: "finance_feeling_headline_clear"
        case .blankSlate: "finance_feeling_headline_blank"
        }
    }

    var reasonLines: [String] {
        var lines: [String] = []

        if summary.overdue > 0 {
            lines.append(String(format: String(localized: "dashboard_overdue_count"), summary.overdue))
        }
        if summary.urgent > 0 {
            lines.append(String(format: String(localized: "dashboard_urgent_count"), summary.urgent))
        }
        if summary.dueSoon > 0 {
            lines.append(String(format: String(localized: "dashboard_due_soon_count"), summary.dueSoon))
        }
        if summary.optimalDay > 0 {
            lines.append(String(format: String(localized: "timeline_summary_optimal_count"), summary.optimalDay))
        }
        if summary.paid > 0 {
            lines.append(String(format: String(localized: "timeline_summary_paid_count"), summary.paid))
        }
        if summary.onTrack > 0 {
            lines.append(String(format: String(localized: "finance_feeling_on_track_count"), summary.onTrack))
        }

        if lines.isEmpty {
            return [String(localized: "finance_feeling_why_blank")]
        }

        return lines
    }
}
