import SwiftUI

enum CalendarSpan: String, CaseIterable, Identifiable {
    case day
    case week
    case month

    var id: String { rawValue }

    var labelKey: LocalizedStringKey {
        switch self {
        case .day: "calendar_span_day"
        case .week: "calendar_span_week"
        case .month: "calendar_span_month"
        }
    }

    var iconName: String {
        switch self {
        case .day: "list.bullet.rectangle"
        case .week: "rectangle.split.3x1"
        case .month: "calendar"
        }
    }

    var stepComponent: Calendar.Component {
        switch self {
        case .day: .day
        case .week: .weekOfYear
        case .month: .month
        }
    }

    var nextAccessibilityKey: LocalizedStringKey {
        switch self {
        case .day: "calendar_a11y_next_day"
        case .week: "calendar_a11y_next_week"
        case .month: "calendar_a11y_next_month"
        }
    }

    var previousAccessibilityKey: LocalizedStringKey {
        switch self {
        case .day: "calendar_a11y_previous_day"
        case .week: "calendar_a11y_previous_week"
        case .month: "calendar_a11y_previous_month"
        }
    }
}
